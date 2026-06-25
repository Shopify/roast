# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    # Chat cog for pure LLM interaction
    #
    # The chat cog provides pure LLM interaction without local system access. While it
    # cannot access local files or run local tools, it can still perform complex reasoning and
    # access any cloud-based tools and MCP servers according to the capabilities of the model and
    # the capabilities that may be provided to it by the LLM provider.
    #
    # Key characteristics:
    # - No access to local filesystem (cannot read or write local files)
    # - Cannot run local tools or commands
    # - Can access cloud-based tools and MCP servers provided by the LLM provider
    # - Performs request-response interactions
    # - Does not currently maintain conversation state across invocations (not yet implemented)
    # - Does not currently support automatic session resumption (not yet implemented)
    #
    # For tasks requiring local filesystem access or locally-configured tools, use the `agent` cog instead.
    class Chat < Cog
      # Raised when the LLM response hits the max token limit, indicating the output was
      # truncated and should not be considered usable.
      class MaxTokensExceededError < Cog::CogError; end

      # Anthropic always sends a max_tokens value in the request payload with this fallback
      # when the model metadata doesn't specify one (see ruby_llm's Anthropic::Chat#build_base_payload).
      ANTHROPIC_DEFAULT_MAX_TOKENS = 4096

      # The configuration object for this chat cog instance
      #
      #: Roast::Cogs::Chat::Config
      attr_reader :config

      # Execute the chat completion with the given input and return the output
      #
      #: (Input) -> Output
      def execute(input)
        chat = ruby_llm_context.chat(
          model: config.valid_model,
          provider: config.valid_provider!,
          assume_model_exists: !config.verify_model_exists?,
        )
        input.valid_session&.apply!(chat)
        chat = chat.with_temperature(config.valid_temperature) if config.valid_temperature
        num_existing_messages = chat.messages.length

        response = chat.ask(input.valid_prompt!)
        chat.messages[num_existing_messages..].each do |message|
          case message.role
          when :user
            Event << { block: { header: "USER PROMPT", content: message.content } } if config.show_prompt?
          when :assistant
            Event << { block: { header: "LLM RESPONSE", content: message.content } } if config.show_response?
          else
            # No other message types are expected, but let's show them if they do appear
            # but only the user has requested some form of output
            Event << { block: { header: "UNKNOWN", content: message.content } } if config.show_prompt? || config.show_response?
          end
        end
        if config.show_stats?
          temperature = chat.instance_variable_get(:@temperature)
          lines = ["Model: #{response.model_id}"]
          lines << "Temperature: #{format("%0.2f", temperature)}" if temperature
          lines << "Input Tokens: #{response.input_tokens}"
          lines << "Output Tokens: #{response.output_tokens}"
          Event << { block: { header: "LLM STATS", content: lines.join("\n") } }
        end

        verify_response_not_truncated!(chat, response)

        Output.new(Session.from_chat(chat), response.content)
      end

      private

      # Verify that the LLM response was not truncated by hitting the max token limit.
      #
      # ruby_llm does not expose a stop_reason/finish_reason from the provider response, so we
      # detect truncation heuristically: if the output token count equals (or exceeds) the
      # effective max token limit, the content was almost certainly cut off mid-generation.
      #
      # The effective limit is derived from the model metadata (chat.model.max_tokens). For
      # Anthropic, the provider always sends max_tokens with a fallback of 4096, so we replicate
      # that fallback here. For other providers, if the model metadata doesn't specify a limit
      # (e.g., when assume_model_exists is used with an unknown model), the check is skipped
      # because we have no ceiling to compare against.
      #
      #: (RubyLLM::Chat, RubyLLM::Message) -> void
      def verify_response_not_truncated!(chat, response)
        max_tokens = effective_max_tokens(chat)
        return unless max_tokens
        return unless response.output_tokens

        if response.output_tokens >= max_tokens
          raise MaxTokensExceededError,
            "LLM response from #{response.model_id} was truncated at the max token limit " \
              "(output: #{response.output_tokens} tokens, limit: #{max_tokens} tokens). " \
              "The response content is likely incomplete and should not be used."
        end
      end

      # Determine the effective max token limit for the chat request.
      #
      # Returns nil if the limit cannot be determined (e.g., the model is not in the registry
      # and the provider doesn't have a known default).
      #
      #: (RubyLLM::Chat) -> Integer?
      def effective_max_tokens(chat)
        max_tokens = chat.model&.max_tokens
        return max_tokens if max_tokens

        # Anthropic always sends max_tokens with a 4096 fallback in the request payload
        ANTHROPIC_DEFAULT_MAX_TOKENS if config.valid_provider! == :anthropic
      end

      # Get a RubyLLM context configured for this chat cog
      #
      #: () -> RubyLLM::Context
      def ruby_llm_context
        @ruby_llm_context ||= RubyLLM.context do |context|
          case config.valid_provider!
          when :openai
            context.openai_api_key = config.valid_api_key!
            context.openai_api_base = config.valid_base_url
          when :anthropic
            context.anthropic_api_key = config.valid_api_key!
            context.anthropic_api_base = config.valid_base_url
          when :perplexity
            context.perplexity_api_key = config.valid_api_key!
          when :gemini
            context.gemini_api_key = config.valid_api_key!
            context.gemini_api_base = config.valid_base_url
          end
        end
      end
    end
  end
end
