# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class ChatMaxTokensTest < ActiveSupport::TestCase
      def setup
        configure_ruby_llm
        @cog = Chat.new(:test, ->(input) { input.prompt = "test message" })
        @cog.config.api_key("dummy-test-key")
        @cog.config.assume_model_exists!
        @cog.config.no_show_prompt!
        @cog.config.no_show_response!
        @cog.config.no_show_stats!
      end

      def make_input
        input = Chat::Input.new
        input.prompt = "test message"
        input
      end

      test "raises MaxTokensExceededError when output tokens equals max tokens for Anthropic" do
        @cog.config.provider(:anthropic)

        stub_registry_max_tokens(4096, :anthropic)
        mock_chat = mock_chat_with_response(output_tokens: 4096)
        stub_ruby_llm_context(mock_chat, :anthropic)

        error = assert_raises(Chat::MaxTokensExceededError) do
          @cog.execute(make_input)
        end

        assert_match(/truncated at the max token limit/, error.message)
        assert_match(/output: 4096 tokens/, error.message)
        assert_match(/limit: 4096 tokens/, error.message)
      end

      test "raises MaxTokensExceededError when output tokens exceeds max tokens" do
        @cog.config.provider(:openai)

        stub_registry_max_tokens(4096, :openai)
        mock_chat = mock_chat_with_response(output_tokens: 4097)
        stub_ruby_llm_context(mock_chat, :openai)

        assert_raises(Chat::MaxTokensExceededError) do
          @cog.execute(make_input)
        end
      end

      test "does not raise when output tokens is below max tokens" do
        @cog.config.provider(:openai)

        stub_registry_max_tokens(4096, :openai)
        mock_chat = mock_chat_with_response(output_tokens: 100)
        stub_ruby_llm_context(mock_chat, :openai)

        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "does not raise when output tokens is one below max tokens" do
        @cog.config.provider(:openai)

        stub_registry_max_tokens(4096, :openai)
        mock_chat = mock_chat_with_response(output_tokens: 4095)
        stub_ruby_llm_context(mock_chat, :openai)

        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "uses Anthropic 4096 fallback when model is not in registry for Anthropic provider" do
        @cog.config.provider(:anthropic)

        stub_registry_not_found(:anthropic)
        mock_chat = mock_chat_with_response(output_tokens: 4096)
        stub_ruby_llm_context(mock_chat, :anthropic)

        assert_raises(Chat::MaxTokensExceededError) do
          @cog.execute(make_input)
        end
      end

      test "does not raise for Anthropic when output is below 4096 fallback" do
        @cog.config.provider(:anthropic)

        stub_registry_not_found(:anthropic)
        mock_chat = mock_chat_with_response(output_tokens: 4000)
        stub_ruby_llm_context(mock_chat, :anthropic)

        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "uses registry max_tokens when available even for Anthropic" do
        @cog.config.provider(:anthropic)

        stub_registry_max_tokens(8192, :anthropic)
        mock_chat = mock_chat_with_response(output_tokens: 4096)
        stub_ruby_llm_context(mock_chat, :anthropic)

        # 4096 < 8192, so no error
        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "raises for Anthropic when output hits registry-specified max_tokens" do
        @cog.config.provider(:anthropic)

        stub_registry_max_tokens(8192, :anthropic)
        mock_chat = mock_chat_with_response(output_tokens: 8192)
        stub_ruby_llm_context(mock_chat, :anthropic)

        assert_raises(Chat::MaxTokensExceededError) do
          @cog.execute(make_input)
        end
      end

      test "skips check when model is not in registry for non-Anthropic provider" do
        @cog.config.provider(:openai)

        stub_registry_not_found(:openai)
        mock_chat = mock_chat_with_response(output_tokens: 999_999)
        stub_ruby_llm_context(mock_chat, :openai)

        # Can't determine the limit, so no error should be raised
        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "skips check when response output_tokens is nil" do
        @cog.config.provider(:openai)

        stub_registry_max_tokens(4096, :openai)
        mock_chat = mock_chat_with_response(output_tokens: nil)
        stub_ruby_llm_context(mock_chat, :openai)

        output = @cog.execute(make_input)
        assert_equal "test response", output.response
      end

      test "MaxTokensExceededError inherits from Cog::CogError" do
        assert Chat::MaxTokensExceededError.ancestors.include?(Cog::CogError)
      end

      private

      def configure_ruby_llm
        RubyLLM.configure do |config|
          config.openai_api_key = "test-key"
          config.anthropic_api_key = "test-key"
        end
      end

      def mock_chat_with_response(output_tokens:)
        mock_chat = mock
        mock_chat.stubs(:messages).returns([])
        mock_chat.stubs(:with_temperature).returns(mock_chat)
        mock_chat.stubs(:ask).returns(
          stub(
            content: "test response",
            model_id: "test-model",
            input_tokens: 10,
            output_tokens: output_tokens,
          ),
        )
        mock_chat
      end

      def stub_ruby_llm_context(mock_chat, provider)
        mock_context = mock
        mock_context.stubs(:chat).returns(mock_chat)
        case provider
        when :openai
          mock_context.stubs(:openai_api_key=)
          mock_context.stubs(:openai_api_base=)
        when :anthropic
          mock_context.stubs(:anthropic_api_key=)
          mock_context.stubs(:anthropic_api_base=)
        end
        RubyLLM.stubs(:context).yields(mock_context).returns(mock_context)
      end

      # Stub the model registry to return a model with the given max_tokens.
      # This tests the production path: effective_max_tokens calls RubyLLM.models.find.
      def stub_registry_max_tokens(max_tokens, provider)
        mock_model = stub(max_tokens: max_tokens)
        mock_models = mock
        mock_models.stubs(:find).returns(mock_model)
        RubyLLM.stubs(:models).returns(mock_models)
      end

      # Stub the model registry to raise ModelNotFoundError, simulating an
      # unknown model. This tests the Anthropic fallback path.
      def stub_registry_not_found(provider)
        mock_models = mock
        mock_models.stubs(:find).raises(RubyLLM::ModelNotFoundError.new("Unknown model"))
        RubyLLM.stubs(:models).returns(mock_models)
      end
    end
  end
end
