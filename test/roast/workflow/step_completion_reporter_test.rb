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
    end
  end
end
