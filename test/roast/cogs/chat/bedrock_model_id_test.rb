# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    # The Bedrock Converse response has no modelId field, so ruby_llm returns a nil model_id for it.
    class ChatBedrockModelIdTest < ActiveSupport::TestCase
      RESOLVED_MODEL = "id-resolved-by-ruby-llm"

      def setup
        @cog = Chat.new(:test, ->(input) { input.prompt = "test message" })
        @cog.config.provider(:bedrock)
        @cog.config.api_key("akid")
        @cog.config.assume_model_exists!
        @cog.config.no_show_prompt!
        @cog.config.no_show_response!
      end

      test "stats show the model ruby_llm sent when the response has no model_id" do
        stub_chat_response(model_id: nil, output_tokens: 10)

        events = capture_events { execute_with_aws_env }

        assert_includes events.to_s, "Model: #{RESOLVED_MODEL}"
      end

      test "stats show the response model_id when the response has one" do
        stub_chat_response(model_id: "reported-model", output_tokens: 10)

        events = capture_events { execute_with_aws_env }

        assert_includes events.to_s, "Model: reported-model"
      end

      test "truncation error names the model ruby_llm sent when the response has no model_id" do
        @cog.config.no_show_stats!
        stub_chat_response(model_id: nil, output_tokens: 64_000)
        RubyLLM.models.stubs(:find).returns(stub(max_tokens: 64_000))

        error = assert_raises(Chat::MaxTokensExceededError) { execute_with_aws_env }

        assert_includes error.message, "LLM response from #{RESOLVED_MODEL} was truncated"
      end

      test "truncation error names the response model_id when the response has one" do
        @cog.config.no_show_stats!
        stub_chat_response(model_id: "reported-model", output_tokens: 64_000)
        RubyLLM.models.stubs(:find).returns(stub(max_tokens: 64_000))

        error = assert_raises(Chat::MaxTokensExceededError) { execute_with_aws_env }

        assert_includes error.message, "LLM response from reported-model was truncated"
      end

      private

      def make_input
        input = Chat::Input.new
        input.prompt = "test message"
        input
      end

      def execute_with_aws_env
        with_env("AWS_SECRET_ACCESS_KEY", "secret") do
          with_env("AWS_REGION", "us-west-2") { @cog.execute(make_input) }
        end
      end

      def capture_events(&block)
        events = []
        Event.stubs(:<<).with { |event| events << event }
        block.call
        events
      end

      def stub_chat_response(model_id:, output_tokens:)
        mock_chat = mock
        mock_chat.stubs(:messages).returns([])
        mock_chat.stubs(:model).returns(stub(id: RESOLVED_MODEL))
        mock_chat.stubs(:with_temperature).returns(mock_chat)
        mock_chat.stubs(:ask).returns(
          stub(content: "test response", model_id: model_id, input_tokens: 10, output_tokens: output_tokens),
        )
        mock_context = mock
        mock_context.stubs(:chat).returns(mock_chat)
        mock_context.stubs(:bedrock_api_key=)
        mock_context.stubs(:bedrock_secret_key=)
        mock_context.stubs(:bedrock_session_token=)
        mock_context.stubs(:bedrock_region=)
        RubyLLM.stubs(:context).yields(mock_context).returns(mock_context)
        Chat::Session.stubs(:from_chat).returns(nil)
      end
    end
  end
end
