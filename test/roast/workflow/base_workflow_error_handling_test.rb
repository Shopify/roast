# typed: false
# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseWorkflowErrorHandlingTest < ActiveSupport::TestCase
      # Mock Faraday error that mimics real Faraday error structure
      class MockFaradayError < StandardError
        attr_reader :response_status, :response_body, :response_headers, :response

        def initialize(message, status: nil, body: nil, headers: nil, url: nil)
          super(message)
          @response_status = status
          @response_body = body
          @response_headers = headers
          @response = { status: status, body: body, headers: headers, url: url } if url
        end
      end

      def setup
        Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
        Roast::Tools.stubs(:setup_interrupt_handler)
        Roast::Tools.stubs(:setup_exit_handler)

        @original_openai_key = ENV["OPENAI_API_KEY"]
        ENV["OPENAI_API_KEY"] = "test-key"

        @test_file = File.join(Dir.pwd, "test/fixtures/files/test.rb")
        @workflow = BaseWorkflow.new(@test_file)
      end

      def teardown
        Roast::Helpers::PromptLoader.unstub(:load_prompt)
        Roast::Tools.unstub(:setup_interrupt_handler)
        Roast::Tools.unstub(:setup_exit_handler)

        ENV["OPENAI_API_KEY"] = @original_openai_key
      end

      test "extract_api_context extracts status, body, and headers from Faraday errors" do
        error = MockFaradayError.new(
          "server error",
          status: 503,
          body: { "error" => { "message" => "Service unavailable", "type" => "service_error" } },
          headers: { "content-type" => "application/json", "retry-after" => "30" },
          url: "https://api.openai.com/v1/chat/completions",
        )

        context = @workflow.send(:extract_api_context, error)

        assert_equal 503, context[:status]
        assert_equal({ "error" => { "message" => "Service unavailable", "type" => "service_error" } }, context[:response_body])
        assert_equal({ "content-type" => "application/json", "retry-after" => "30" }, context[:headers])
        assert_equal "https://api.openai.com/v1/chat/completions", context[:url]
      end

      test "extract_api_context handles partial error information gracefully" do
        # Error with only status
        error = MockFaradayError.new("server error", status: 500)
        context = @workflow.send(:extract_api_context, error)

        assert_equal 500, context[:status]
        assert_nil context[:response_body]
        assert_nil context[:headers]

        # Error with only body
        error = MockFaradayError.new("server error", body: "Bad gateway")
        context = @workflow.send(:extract_api_context, error)

        assert_nil context[:status]
        assert_equal "Bad gateway", context[:response_body]
      end

      test "extract_api_context infers API URL from provider configuration" do
        # Test with OpenAI provider
        @workflow.instance_variable_set(
          :@workflow_configuration,
          Struct.new(:api_provider).new(:openai),
        )

        error = StandardError.new("API error")
        context = @workflow.send(:extract_api_context, error)

        assert_equal "https://api.openai.com/v1/chat/completions", context[:url]

        # Test with OpenRouter provider
        @workflow.instance_variable_set(
          :@workflow_configuration,
          Struct.new(:api_provider).new(:openrouter),
        )

        context = @workflow.send(:extract_api_context, error)
        assert_equal "https://openrouter.ai/api/v1/chat/completions", context[:url]
      end

      test "enhance_error_message creates detailed error with full context" do
        api_context = {
          url: "https://api.openai.com/v1/chat/completions",
          status: 429,
          response_body: { "error" => { "message" => "Rate limit exceeded" } },
        }

        enhanced = @workflow.send(:enhance_error_message, "Request failed", api_context)

        assert_includes enhanced, "API call to https://api.openai.com/v1/chat/completions"
        assert_includes enhanced, "failed with status 429"
        assert_includes enhanced, "Rate limit exceeded"
      end

      test "enhance_error_message handles missing URL gracefully" do
        api_context = {
          status: 502,
          response_body: "Bad Gateway",
        }

        enhanced = @workflow.send(:enhance_error_message, "Connection error", api_context)

        assert_includes enhanced, "API call failed with status 502"
        assert_includes enhanced, "Bad Gateway"
        refute_includes enhanced, "https://" # Should not include URL if not available
      end

      test "enhance_error_message handles long response bodies by truncating" do
        api_context = {
          status: 500,
          response_body: "A" * 600, # Very long error message
        }

        enhanced = @workflow.send(:enhance_error_message, "Error", api_context)

        # Should not include very long response bodies
        refute_includes enhanced, "A" * 600
        assert_includes enhanced, "API call failed with status 500"
      end

      test "enhance_error_message returns original when no context available" do
        enhanced = @workflow.send(:enhance_error_message, "Original error", {})
        assert_equal "Original error", enhanced
      end

      test "log_and_raise_error sends notification with API context" do
        error = MockFaradayError.new(
          "API request failed",
          status: 500,
          body: { "error" => { "message" => "Internal error" } },
          url: "https://api.openai.com/v1/chat/completions",
        )

        api_context = {
          url: "https://api.openai.com/v1/chat/completions",
          status: 500,
          response_body: { "error" => { "message" => "Internal error" } },
        }

        events = []
        ActiveSupport::Notifications.subscribe("roast.chat_completion.error") do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        assert_raises(MockFaradayError) do
          request_details = { model: "gpt-4", params: {}, execution_time: 1.5 }
          @workflow.send(:log_and_raise_error, error, "Enhanced message", request_details, api_context)
        end

        assert_equal 1, events.length
        event = events.first

        assert_equal "Roast::Workflow::BaseWorkflowErrorHandlingTest::MockFaradayError", event.payload[:error]
        assert_equal "Enhanced message", event.payload[:message]
        assert_equal "gpt-4", event.payload[:model]
        assert_equal 1.5, event.payload[:execution_time]
        assert_equal "https://api.openai.com/v1/chat/completions", event.payload[:api_url]
        assert_equal 500, event.payload[:status_code]
        assert_equal({ "error" => { "message" => "Internal error" } }, event.payload[:response_body])

        ActiveSupport::Notifications.unsubscribe("roast.chat_completion.error")
      end

      test "log_and_raise_error creates new error with enhanced message" do
        original_error = StandardError.new("Original message")
        # Give the error a backtrace by raising and catching it
        begin
          raise original_error
        rescue => e
          original_error = e
        end

        enhanced_message = "Enhanced: Original message with more context"

        exception = assert_raises(StandardError) do
          request_details = { model: nil, params: {}, execution_time: 0.1 }
          @workflow.send(:log_and_raise_error, original_error, enhanced_message, request_details, {})
        end

        assert_equal enhanced_message, exception.message
        assert_equal original_error.class, exception.class
        assert_equal original_error.backtrace, exception.backtrace
      end

      test "log_and_raise_error preserves original error when message unchanged" do
        original_error = StandardError.new("Same message")

        exception = assert_raises(StandardError) do
          request_details = { model: nil, params: {}, execution_time: 0.1 }
          @workflow.send(:log_and_raise_error, original_error, "Same message", request_details, {})
        end

        assert_same original_error, exception
      end
    end
  end
end
