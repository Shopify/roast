# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class SessionManager
      attr_reader :messages, :metadata, :tool_calls_history

      def initialize
        @messages = []
        @metadata = {}
        @tool_calls_history = []
        @message_id_counter = 0
      end

      def add_system_message(content)
        add_message(role: "system", content: content)
      end

      def add_user_message(content)
        add_message(role: "user", content: content)
      end

      def add_assistant_message(content, tool_calls: nil)
        message = { role: "assistant", content: content }
        message[:tool_calls] = tool_calls if tool_calls && !tool_calls.empty?
        add_message(message)
      end

      def add_tool_message(tool_call_id, content)
        add_message(role: "tool", tool_call_id: tool_call_id, content: content)
      end

      def add_message(message)
        message = message.transform_keys(&:to_sym)
        message[:timestamp] = Time.now
        message[:id] = next_message_id
        
        @messages << message
        
        # Track tool calls for analysis
        if message[:tool_calls]
          @tool_calls_history.concat(message[:tool_calls])
        end
        
        message
      end

      def get_messages(limit: nil, include_system: true)
        filtered = if include_system
          @messages
        else
          @messages.reject { |m| m[:role] == "system" }
        end
        
        limit ? filtered.last(limit) : filtered
      end

      def get_context_messages(max_tokens: 4000, model: "gpt-4")
        # Intelligently select messages that fit within token limit
        # Priority: system messages, recent messages, important tool results
        
        selected = []
        token_count = 0
        
        # Always include system messages
        system_messages = @messages.select { |m| m[:role] == "system" }
        system_messages.each do |msg|
          tokens = estimate_tokens(msg, model)
          if token_count + tokens <= max_tokens
            selected << msg
            token_count += tokens
          end
        end
        
        # Add recent messages in reverse order
        recent_messages = @messages.reject { |m| m[:role] == "system" }.reverse
        
        recent_messages.each do |msg|
          tokens = estimate_tokens(msg, model)
          if token_count + tokens <= max_tokens
            selected.unshift(msg)
            token_count += tokens
          else
            # Try to add a truncated version
            truncated = truncate_message(msg, max_tokens - token_count, model)
            if truncated
              selected.unshift(truncated)
              break
            end
          end
        end
        
        # Sort by original order
        selected.sort_by { |m| m[:id] }
      end

      def clear
        @messages.clear
        @tool_calls_history.clear
        @metadata.clear
        @message_id_counter = 0
      end

      def export(format: :json)
        case format
        when :json
          export_as_json
        when :markdown
          export_as_markdown
        else
          raise ArgumentError, "Unsupported export format: #{format}"
        end
      end

      def import(data, format: :json)
        case format
        when :json
          import_from_json(data)
        else
          raise ArgumentError, "Unsupported import format: #{format}"
        end
      end

      def token_count(model: "gpt-4")
        @messages.sum { |msg| estimate_tokens(msg, model) }
      end

      def conversation_summary
        {
          message_count: @messages.length,
          user_messages: @messages.count { |m| m[:role] == "user" },
          assistant_messages: @messages.count { |m| m[:role] == "assistant" },
          tool_calls: @tool_calls_history.length,
          total_tokens: token_count,
          duration: conversation_duration,
          metadata: @metadata
        }
      end

      def save_to_file(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, export_as_json)
      end

      def load_from_file(path)
        raise "Session file not found: #{path}" unless File.exist?(path)
        import_from_json(File.read(path))
      end

      private

      def next_message_id
        @message_id_counter += 1
      end

      def estimate_tokens(message, model)
        # Rough estimation: ~4 characters per token for English
        # This should be replaced with proper tokenization for production
        content = message[:content] || ""
        
        if message[:tool_calls]
          content += message[:tool_calls].map { |tc| tc.to_json }.join
        end
        
        (content.length / 4.0).ceil
      end

      def truncate_message(message, max_tokens, model)
        return nil if max_tokens <= 0
        
        content = message[:content] || ""
        estimated_chars = max_tokens * 4
        
        if content.length > estimated_chars
          truncated_content = content[0...estimated_chars] + "..."
          message.merge(content: truncated_content, truncated: true)
        else
          message
        end
      end

      def export_as_json
        require "json"
        require "time"
        
        JSON.pretty_generate({
          version: "1.0",
          exported_at: Time.now.iso8601,
          metadata: @metadata,
          messages: @messages.map do |msg|
            msg.reject { |k, _| k == :id }
          end,
          tool_calls_history: @tool_calls_history
        })
      end

      def export_as_markdown
        require "time"
        lines = ["# Conversation Export", ""]
        lines << "**Exported at:** #{Time.now.iso8601}"
        lines << ""
        
        if @metadata.any?
          lines << "## Metadata"
          @metadata.each do |key, value|
            lines << "- **#{key}:** #{value}"
          end
          lines << ""
        end
        
        lines << "## Messages"
        lines << ""
        
        @messages.each do |msg|
          role_label = msg[:role].capitalize
          timestamp = msg[:timestamp].strftime("%Y-%m-%d %H:%M:%S")
          
          lines << "### #{role_label} (#{timestamp})"
          lines << ""
          lines << msg[:content] if msg[:content]
          
          if msg[:tool_calls]
            lines << ""
            lines << "**Tool Calls:**"
            msg[:tool_calls].each do |tc|
              lines << "- #{tc[:function][:name]}(#{tc[:function][:arguments]})"
            end
          end
          
          lines << ""
        end
        
        lines.join("\n")
      end

      def import_from_json(json_string)
        require "json"
        
        data = JSON.parse(json_string, symbolize_names: true)
        
        clear
        
        @metadata = data[:metadata] || {}
        
        data[:messages]&.each do |msg|
          msg[:timestamp] = Time.parse(msg[:timestamp]) if msg[:timestamp].is_a?(String)
          add_message(msg)
        end
        
        @tool_calls_history = data[:tool_calls_history] || []
        
        self
      end

      def conversation_duration
        return 0 if @messages.empty?
        
        first_timestamp = @messages.first[:timestamp]
        last_timestamp = @messages.last[:timestamp]
        
        (last_timestamp - first_timestamp).to_i
      end
    end
  end
end