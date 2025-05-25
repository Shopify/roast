# frozen_string_literal: true

require "roast/workflow/model_config"
require "active_support/notifications"

module Roast
  module Workflow
    class ContextManager
      attr_reader :config, :model

      def initialize(config:, model:)
        @config = config
        @model = model
      end

      def max_tokens
        return config.max_tokens if config.max_tokens
        ModelConfig.max_tokens_for(model)
      end

      def token_threshold
        (max_tokens * config.threshold).to_i
      end

      def post_compaction_target
        (token_threshold * config.post_compaction_threshold_buffer).to_i
      end

      def count_tokens(text)
        return 0 if text.nil? || text.empty?
        
        if openai_model?
          count_tokens_with_tiktoken(text)
        else
          count_tokens_with_ratio(text)
        end
      end

      def count_transcript_tokens(transcript)
        return 0 if transcript.nil? || transcript.empty?
        
        total_tokens = 0
        transcript.each do |message|
          next unless message.is_a?(Hash)
          
          content = message["content"] || message[:content]
          total_tokens += count_tokens(content.to_s) if content
          
          # Count role tokens (small overhead)
          role = message["role"] || message[:role]
          total_tokens += count_tokens(role.to_s) if role
        end
        
        total_tokens
      end

      def needs_compaction?(transcript)
        return false unless config.enabled
        count_transcript_tokens(transcript) >= token_threshold
      end

      def compact_transcript(transcript)
        return transcript unless needs_compaction?(transcript)
        
        # Capture metrics before compaction
        original_tokens = count_transcript_tokens(transcript)
        original_messages = transcript.length
        
        compacted_transcript = case config.strategy
        when "truncation"
          truncate_transcript(transcript)
        when "llm_summarization"
          summarize_transcript_with_llm(transcript)
        else
          raise ArgumentError, "Unknown compaction strategy: #{config.strategy}"
        end
        
        # Emit instrumentation event
        new_tokens = count_transcript_tokens(compacted_transcript)
        new_messages = compacted_transcript.length
        tokens_saved = original_tokens - new_tokens
        
        ActiveSupport::Notifications.instrument("roast.context_compaction", {
          strategy: config.strategy,
          original_messages: original_messages,
          new_messages: new_messages,
          original_tokens: original_tokens,
          new_tokens: new_tokens,
          tokens_saved: tokens_saved
        })
        
        compacted_transcript
      end

      private

      def openai_model?
        model.to_s.start_with?("gpt-")
      end

      def count_tokens_with_tiktoken(text)
        begin
          require "tiktoken_ruby"
          encoding = Tiktoken.encoding_for_model(model)
          encoding.encode(text).length
        rescue LoadError
          # Fallback to character ratio if tiktoken_ruby is not available
          count_tokens_with_ratio(text)
        rescue => e
          # If tiktoken fails for any reason, fallback to character ratio
          count_tokens_with_ratio(text)
        end
      end

      def count_tokens_with_ratio(text)
        ratio = model_character_to_token_ratio
        (text.length * ratio).ceil
      end
      
      def model_character_to_token_ratio
        # First try to get model-specific ratio
        model_ratio = ModelConfig.character_to_token_ratio_for(model)
        return model_ratio if model_ratio
        
        # Fall back to configuration ratio if model doesn't have one
        config.character_to_token_ratio || 0.25
      end

      def truncate_transcript(transcript)
        return transcript if transcript.empty?
        
        # Always preserve the first message (system prompt)
        system_message = transcript.first
        remaining_messages = transcript[1..]
        
        # Calculate tokens for system message
        system_tokens = count_tokens(system_message["content"] || system_message[:content] || "")
        target_tokens = post_compaction_target - system_tokens
        
        # Truncate from the beginning of remaining messages
        current_tokens = 0
        preserved_messages = []
        
        # Work backwards through remaining messages to preserve recent context
        remaining_messages.reverse.each do |message|
          message_tokens = count_tokens(message["content"] || message[:content] || "")
          if current_tokens + message_tokens <= target_tokens
            preserved_messages.unshift(message)
            current_tokens += message_tokens
          else
            break
          end
        end
        
        # Create compaction marker
        removed_count = remaining_messages.length - preserved_messages.length
        removed_tokens = count_transcript_tokens(remaining_messages) - current_tokens
        
        compaction_marker = {
          "role" => "system",
          "content" => "[CONTEXT REDUCED: Truncated #{removed_tokens} tokens, #{removed_count} messages removed]"
        }
        
        # Return new transcript
        [system_message, compaction_marker] + preserved_messages
      end

      def summarize_transcript_with_llm(transcript)
        return transcript if transcript.empty?
        
        # Always preserve the first message (system prompt)
        system_message = transcript.first
        remaining_messages = transcript[1..]
        
        return transcript if remaining_messages.empty?
        
        # Calculate how many messages to summarize
        current_tokens = count_transcript_tokens(transcript)
        target_tokens = post_compaction_target
        tokens_to_remove = current_tokens - target_tokens
        
        # Find messages to summarize (from oldest, excluding recent context)
        messages_to_summarize = []
        tokens_being_summarized = 0
        
        remaining_messages.each do |message|
          message_tokens = count_tokens(message["content"] || message[:content] || "")
          if tokens_being_summarized < tokens_to_remove
            messages_to_summarize << message
            tokens_being_summarized += message_tokens
          else
            break
          end
        end
        
        return transcript if messages_to_summarize.empty?
        
        # Create summarization prompt
        messages_content = messages_to_summarize.map { |msg| msg["content"] || msg[:content] }.join("\n\n")
        summarization_prompt = build_summarization_prompt(messages_content)
        
        # Use the workflow's LLM to generate the actual summary
        summary_content = generate_llm_summary(summarization_prompt)
        
        # Create summary message and compaction marker
        summary_message = {
          "role" => "assistant",
          "content" => summary_content
        }
        
        compaction_marker = {
          "role" => "system",
          "content" => "[CONTEXT REDUCED: Summarized #{tokens_being_summarized} tokens into #{count_tokens(summary_content)} tokens]"
        }
        
        # Return new transcript
        preserved_messages = remaining_messages[messages_to_summarize.length..]
        [system_message, compaction_marker, summary_message] + preserved_messages
      end

      def build_summarization_prompt(content)
        <<~PROMPT
          Please provide a concise summary of the following conversation content, preserving the key information, decisions made, and important context that would be needed to continue the conversation effectively:

          #{content}

          Summary:
        PROMPT
      end

      def generate_llm_summary(prompt)
        # Create a temporary transcript for summarization
        summarization_transcript = [
          { "role" => "user", "content" => prompt }
        ]
        
        # Save current transcript and temporarily use the summarization one
        original_transcript = @workflow.transcript
        @workflow.transcript = summarization_transcript
        
        begin
          # Use a smaller, faster model for summarization if available
          summarization_model = get_summarization_model
          
          # Make the LLM call with reduced parameters to avoid recursion
          response = @workflow.with_model(summarization_model) do
            # Temporarily disable context management to prevent infinite recursion
            original_manager = @workflow.instance_variable_get(:@context_manager)
            @workflow.instance_variable_set(:@context_manager, nil)
            
            begin
              @workflow.chat_completion(
                messages: summarization_transcript,
                temperature: 0.3,  # Lower temperature for more consistent summaries
                max_tokens: 500    # Reasonable limit for summaries
              )
            ensure
              # Restore context manager
              @workflow.instance_variable_set(:@context_manager, original_manager)
            end
          end
          
          response || create_fallback_summary(prompt)
        rescue => e
          # If LLM call fails, fall back to a simple summary
          create_fallback_summary(prompt)
        ensure
          # Always restore the original transcript
          @workflow.transcript = original_transcript
        end
      end
      
      def get_summarization_model
        # Use explicit override if provided
        return config.summarization_model if config.summarization_model
        
        # Simple model selection: try to find a "mini" or "flash" variant, otherwise use main model
        model_str = @model.to_s.downcase
        
        # If already using a fast model, keep using it
        return @model if model_str.include?("mini") || model_str.include?("haiku") || 
                        (model_str.include?("flash") && !model_str.match?(/(?:exp|preview)/))
        
        # Otherwise, select a fast variant based on provider
        case model_str
        when /gpt/, /openai/
          "gpt-4o-mini"
        when /claude/, /anthropic/
          "claude-3-5-haiku-20241022"
        when /gemini/, /google/
          "gemini-2.0-flash"
        else
          # Default fallback for unknown providers
          "gemini-2.0-flash"
        end
      end
      
      def create_fallback_summary(prompt)
        # Extract key information from the prompt for a basic summary
        content_lines = prompt.lines
        content_start = content_lines.find_index { |line| line.strip.length > 0 && !line.include?("Summary:") }
        
        if content_start
          first_part = content_lines[content_start...content_start + 3].join.strip
          "Summary: #{first_part[0..200]}..." + (first_part.length > 200 ? " [Content summarized due to LLM unavailability]" : "")
        else
          "Summary: Previous conversation context has been compacted to manage token usage."
        end
      end
      
      def create_placeholder_summary(messages)
        message_count = messages.length
        "Summary of #{message_count} previous messages: [Conversation context has been summarized to reduce token usage. Key decisions and information have been preserved.]"
      end
    end
  end
end