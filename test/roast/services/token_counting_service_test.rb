# frozen_string_literal: true

require "test_helper"

module Roast
  module Services
    class TokenCountingServiceTest < ActiveSupport::TestCase
      def setup
        @service = TokenCountingService.new
      end

      test "counts tokens in a simple message" do
        messages = [{ role: "user", content: "Hello, world!" }]

        token_count = @service.count_messages(messages)

        assert token_count > 0
        assert_kind_of Integer, token_count
      end

      test "counts tokens in multiple messages" do
        messages = [
          { role: "system", content: "You are a helpful assistant." },
          { role: "user", content: "What is the weather today?" },
          { role: "assistant", content: "I don't have access to current weather data." },
        ]

        token_count = @service.count_messages(messages)

        assert token_count > 20
      end

      test "counts tokens with empty messages" do
        messages = []

        token_count = @service.count_messages(messages)

        assert_equal 0, token_count
      end

      test "handles messages with nil content" do
        messages = [{ role: "user", content: nil }]

        token_count = @service.count_messages(messages)

        # Should still count role tokens even if content is nil
        assert token_count > 0
        assert token_count < 10 # Should be minimal
      end

      test "estimates tokens using character-based ratio" do
        # Average ratio is ~4 characters per token for English text
        messages = [{ role: "user", content: "a" * 400 }]

        token_count = @service.count_messages(messages)

        # Should be approximately 100 tokens (400 chars / 4)
        assert_in_delta 100, token_count, 20
      end

      test "includes role tokens in count" do
        messages = [{ role: "user", content: "Hi" }]

        token_count = @service.count_messages(messages)

        # Should count both role and content tokens
        assert token_count > 1
      end

      test "handles tool messages with function content" do
        messages = [
          { role: "function", name: "get_weather", content: '{"temp": 72, "conditions": "sunny"}' },
        ]

        token_count = @service.count_messages(messages)

        assert token_count > 0
      end

      test "counts tokens for agent calls with prompt and response" do
        prompt = "Review this code and suggest improvements"
        response = "I found several issues that need attention. Consider refactoring the main loop."

        token_count = @service.count_agent_call(prompt, response)

        assert token_count > 0
        assert_kind_of Integer, token_count
      end

      test "returns zero for nil agent call prompt" do
        token_count = @service.count_agent_call(nil)

        assert_equal 0, token_count
      end
    end
  end
end
