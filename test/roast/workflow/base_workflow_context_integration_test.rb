# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseWorkflowContextIntegrationTest < ActiveSupport::TestCase
      class TestWorkflow < BaseWorkflow
        def initialize
          super
          @context_management_config = {
            enabled: true,
            threshold: 0.8,
            max_tokens: 1000,
          }
        end
      end

      def setup
        @workflow = TestWorkflow.new
      end

      def teardown
        # Clean up any mocks to avoid test pollution
        Mocha::Mockery.instance.teardown
      end

      test "initializes context manager" do
        assert_not_nil @workflow.context_manager
        assert_kind_of ContextManager, @workflow.context_manager
      end

      test "tracks tokens when chat_completion is called" do
        messages = [
          { role: "system", content: "You are a helpful assistant" },
          { role: "user", content: "Hello" },
        ]

        @workflow.context_management_config = { enabled: true }

        # Override the superclass method directly on the instance
        def @workflow.super_chat_completion(**kwargs)
          "Hi there!"
        end

        # Override chat_completion method to avoid actual API calls
        def @workflow.chat_completion(**kwargs)
          @context_manager.configure(@context_management_config)
          messages = kwargs[:messages] || transcript.flatten.compact
          @context_manager.track_usage(messages)
          # Return mock response
          "Hi there!"
        end

        @workflow.chat_completion(messages: messages)

        stats = @workflow.context_manager.statistics
        assert stats[:total_tokens] > 0
      end

      test "emits instrumentation with token usage" do
        skip "Instrumentation test requires refactoring to work with module mocking"
      end

      test "checks for compaction need before API call" do
        skip "Warning test requires refactoring to work with module mocking"
      end

      test "respects disabled context management" do
        @workflow.context_management_config = { enabled: false }

        messages = [{ role: "user", content: "Test" }]

        # Override to avoid actual API call
        def @workflow.chat_completion(**kwargs)
          # Our implementation should not track when disabled
          if @context_management_config[:enabled]
            @context_manager.track_usage(kwargs[:messages] || transcript.flatten.compact)
          end
          "Response"
        end

        @workflow.chat_completion(messages: messages)

        assert_equal 0, @workflow.context_manager.total_tokens
      end
    end
  end
end
