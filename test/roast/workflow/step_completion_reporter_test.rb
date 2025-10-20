# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepCompletionReporterTest < ActiveSupport::TestCase
      def setup
        @output = StringIO.new
        @reporter = StepCompletionReporter.new(output: @output)
      end

      test "reports completion with formatted token numbers" do
        @reporter.report("test_step", 1234, 5678)

        assert_equal "✓ Complete: test_step (consumed 1,234 tokens, total 5,678)\n\n\n", @output.string
      end

      test "formats large numbers with commas" do
        @reporter.report("big_step", 1234567, 9876543)

        assert_equal "✓ Complete: big_step (consumed 1,234,567 tokens, total 9,876,543)\n\n\n", @output.string
      end

      test "handles zero token consumption" do
        @reporter.report("no_tokens", 0, 100)

        assert_equal "✓ Complete: no_tokens (consumed 0 tokens, total 100)\n\n\n", @output.string
      end

      test "uses stderr by default" do
        # Capture stderr
        original_stderr = $stderr
        captured_output = StringIO.new
        $stderr = captured_output

        # Create reporter without specifying output
        reporter = StepCompletionReporter.new
        reporter.report("test", 10, 20)

        assert_equal("✓ Complete: test (consumed 10 tokens, total 20)\n\n\n", captured_output.string)
      ensure
        $stderr = original_stderr
      end

      test "includes agent token breakdown when context manager provided with agent usage" do
        context_manager = mock("context_manager")
        context_manager.expects(:statistics).returns(total_tokens: 500, general_tokens: 300, agent_tokens: 200)

        @reporter.report("step_with_agents", 150, 500, context_manager: context_manager)

        expected = "✓ Complete: step_with_agents (consumed 150 tokens, total 500) [general: 300, agent: 200]\n\n\n"
        assert_equal expected, @output.string
      end

      test "does not include breakdown when no agent tokens used" do
        context_manager = mock("context_manager")
        context_manager.expects(:statistics).returns(total_tokens: 300, general_tokens: 300, agent_tokens: 0)

        @reporter.report("step_no_agents", 100, 300, context_manager: context_manager)

        expected = "✓ Complete: step_no_agents (consumed 100 tokens, total 300)\n\n\n"
        assert_equal expected, @output.string
      end
    end
  end
end
