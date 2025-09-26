# typed: false
# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseWorkflowErrorHandlingTest < ActiveSupport::TestCase
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

      test "enhanced_message extracts status and URL from Faraday errors with response hash" do
        error = MockFaradayError.new(
          "server error",
          status: 503,
          body: { "error" => { "message" => "Service unavailable", "type" => "service_error" } },
          headers: { "content-type" => "application/json", "retry-after" => "30" },
          url: "https://api.openai.com/v1/chat/completions",
        )

        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call to https://api.openai.com/v1/chat/completions"
        assert_includes enhanced, "failed with status 503"
        assert_includes enhanced, "server error"
        assert_includes enhanced, "Service unavailable"
      end

      test "enhanced_message handles errors with only response_status" do
        error = MockFaradayError.new("server error", status: 500)
        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call failed with status 500"
        assert_includes enhanced, "server error"
        error = StandardError.new("simple error")
        enhanced = @workflow.send(:enhanced_message, error)
        assert_equal "simple error", enhanced
      end

      test "enhanced_message handles errors with response body details" do
        error = MockFaradayError.new(
          "API request failed",
          status: 429,
          body: { "error" => { "message" => "Rate limit exceeded" } },
          url: "https://api.openai.com/v1/chat/completions",
        )

        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call to https://api.openai.com/v1/chat/completions"
        assert_includes enhanced, "failed with status 429"
        assert_includes enhanced, "API request failed"
        assert_includes enhanced, "Rate limit exceeded"
      end

      test "enhanced_message creates detailed error with full context" do
        error = MockFaradayError.new(
          "Request failed",
          status: 429,
          body: { "error" => { "message" => "Rate limit exceeded" } },
          url: "https://api.openai.com/v1/chat/completions",
        )

        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call to https://api.openai.com/v1/chat/completions"
        assert_includes enhanced, "failed with status 429"
        assert_includes enhanced, "Rate limit exceeded"
      end

      test "enhanced_message handles missing URL gracefully" do
        error = MockFaradayError.new(
          "Connection error",
          status: 502,
          body: "Bad Gateway",
        )

        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call failed with status 502"
        assert_includes enhanced, "Bad Gateway"
        refute_includes enhanced, "https://"
      end

      test "enhanced_message includes response body when available" do
        error = MockFaradayError.new(
          "Error",
          status: 500,
          body: "Internal server error",
        )

        enhanced = @workflow.send(:enhanced_message, error)

        assert_includes enhanced, "API call failed with status 500"
        assert_includes enhanced, "Internal server error"
      end

      test "enhanced_message returns original when no context available" do
        error = StandardError.new("Original error")
        enhanced = @workflow.send(:enhanced_message, error)
        assert_equal "Original error", enhanced
      end

      test "log_and_raise_error sends notification with error details" do
        error = MockFaradayError.new(
          "API request failed",
          status: 500,
          body: { "error" => { "message" => "Internal error" } },
          url: "https://api.openai.com/v1/chat/completions",
        )

        events = []
        ActiveSupport::Notifications.subscribe("roast.chat_completion.error") do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        assert_raises(MockFaradayError) do
          @workflow.send(:log_and_raise_error, error, "Enhanced message", "gpt-4", { some: "params" }, 1.5)
        end

        assert_equal 1, events.length
        event = events.first

        assert_equal "Roast::Workflow::BaseWorkflowErrorHandlingTest::MockFaradayError", event.payload[:error]
        assert_equal "Enhanced message", event.payload[:message]
        assert_equal "gpt-4", event.payload[:model]
        assert_equal 1.5, event.payload[:execution_time]
        assert_equal({ some: "params" }, event.payload[:parameters])

        ActiveSupport::Notifications.unsubscribe("roast.chat_completion.error")
      end

      test "log_and_raise_error creates new error with enhanced message" do
        original_error = StandardError.new("Original message")
        begin
          raise original_error
        rescue => e
          original_error = e
        end

        enhanced_message_text = "Enhanced: Original message with more context"

        exception = assert_raises(StandardError) do
          @workflow.send(:log_and_raise_error, original_error, enhanced_message_text, "gpt-4", {}, 0.1)
        end

        assert_equal enhanced_message_text, exception.message
        assert_equal original_error.class, exception.class
        assert_equal original_error.backtrace, exception.backtrace
      end

      test "log_and_raise_error preserves original error when message unchanged" do
        original_error = StandardError.new("Same message")

        exception = assert_raises(StandardError) do
          @workflow.send(:log_and_raise_error, original_error, "Same message", nil, {}, 0.1)
        end

        assert_same original_error, exception
      end
    end
  end
end
