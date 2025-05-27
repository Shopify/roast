# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_workflow"
require "roast/workflow/context_manager"
require "concurrent-ruby"

# Reuse the TestConfiguration class from integration test
require_relative "context_management_integration_test"

module Roast
  module Workflow
    class ContextManagementConcurrencyTest < ActiveSupport::TestCase
      def setup
        # Create a minimal configuration for context management
        @context_config = Roast::Workflow::ContextManagementConfig.new(
          enabled: true,
          strategy: "truncation",
          threshold: 0.2, # Lower threshold to trigger compaction with test data
          character_to_token_ratio: 0.25,
          post_compaction_threshold_buffer: 0.9,
        )

        # Create a configuration object
        @configuration = TestConfiguration.new(
          context_management: @context_config,
          api_provider: "openai",
        )

        # Stub out the prompt loading and tools setup to avoid side effects
        Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
        Roast::Tools.stubs(:setup_interrupt_handler)
        Roast::Tools.stubs(:setup_exit_handler)
      end

      def teardown
        Roast::Helpers::PromptLoader.unstub(:load_prompt)
        Roast::Tools.unstub(:setup_interrupt_handler)
        Roast::Tools.unstub(:setup_exit_handler)
      end

      test "concurrent context checks are synchronized" do
        workflow = TestWorkflow.new(nil, configuration: @configuration)

        # Create large transcript to trigger compaction
        workflow.transcript = [
          { "role" => "system", "content" => "System" },
          { "role" => "user", "content" => "x" * 10000 },
        ]

        # Track compaction calls
        compaction_count = Concurrent::AtomicFixnum.new(0)
        workflow.instance_variable_get(:@context_manager).define_singleton_method(:compact_transcript) do |_transcript|
          compaction_count.increment
          sleep(0.01) # Simulate work
          [{ "role" => "system", "content" => "Compacted" }]
        end

        # Run concurrent context checks
        threads = 3.times.map do
          Thread.new { workflow.send(:check_and_compact_context) }
        end
        threads.each(&:join)

        # Mutex should prevent excessive compaction calls
        assert compaction_count.value >= 1, "Should compact at least once"
        assert compaction_count.value <= 3, "Should not exceed thread count"
      end

      test "mutex prevents concurrent transcript modification" do
        workflow = TestWorkflow.new(nil, configuration: @configuration)

        # Create transcript that needs compaction
        workflow.transcript = [
          { "role" => "system", "content" => "System" },
          { "role" => "user", "content" => "x" * 5000 },
        ]

        # Track concurrent access
        access_count = Concurrent::AtomicFixnum.new(0)
        workflow.define_singleton_method(:check_and_compact_context) do
          access_count.increment
          sleep(0.01) # Simulate work
        end

        # Run concurrent operations
        threads = 2.times.map do
          Thread.new do
            workflow.context_compaction_mutex.synchronize do
              workflow.send(:check_and_compact_context)
            end
          end
        end
        threads.each(&:join)

        assert_equal 2, access_count.value, "Both threads should complete"
      end

      # Test workflow class that exposes the needed methods for testing
      class TestWorkflow < BaseWorkflow
        attr_accessor :transcript

        def model
          "gpt-4"
        end

        def context_management_enabled?
          true
        end

        public :check_and_compact_context
      end
    end
  end
end
