# typed: true
# frozen_string_literal: true

module Roast
  module Services
    class TokenCountingService
      # Approximate character-to-token ratio for English text
      # Based on OpenAI's rule of thumb: ~4 characters per token
      CHARS_PER_TOKEN = 4.0

      # Base token overhead for message structure
      MESSAGE_OVERHEAD_TOKENS = 3

      # Additional overhead for agent system prompts and structure. Maybe there's a better way to estimate this?
      AGENT_OVERHEAD = 10

      def count_messages(messages)
        return 0 if messages.nil? || messages.empty?

        messages.sum do |message|
          count_message(message)
        end
      end

      def count_agent_call(prompt, response = nil)
        return 0 if prompt.nil? || prompt.empty?

        prompt_tokens = estimate_tokens(prompt.to_s)
        response_tokens = response ? estimate_tokens(response.to_s) : 0

        prompt_tokens + response_tokens + AGENT_OVERHEAD
      end

      private

      def count_message(message)
        return 0 if message.nil?

        role_tokens = estimate_tokens(message[:role].to_s)
        content_tokens = estimate_tokens(message[:content].to_s)

        # Don't add overhead for empty messages
        return 0 if role_tokens == 0 && content_tokens == 0

        # Add overhead for message structure and special tokens
        role_tokens + content_tokens + MESSAGE_OVERHEAD_TOKENS
      end

      def estimate_tokens(text)
        return 0 if text.nil? || text.empty?

        # Simple character-based estimation
        (text.length / CHARS_PER_TOKEN).ceil
      end
    end
  end
end
