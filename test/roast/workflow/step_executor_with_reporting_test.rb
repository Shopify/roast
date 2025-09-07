# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepExecutorWithReportingTest < ActiveSupport::TestCase
      def setup
        @base_executor = mock("base_executor")
        @context = mock("context")
        @workflow = mock("workflow")
        @workflow.stubs(:metadata).returns({})
        @context_manager = mock("context_manager")

        @context.stubs(:workflow).returns(@workflow)
        @workflow.stubs(:context_manager).returns(@context_manager)

        @output = StringIO.new
        @executor = StepExecutorWithReporting.new(@base_executor, @context, output: @output)
      end

      test "delegates execution to base executor" do
        step = "my_step"

        @base_executor.expects(:execute).with(step, is_last_step: true).returns("result")
        @context_manager.stubs(:total_tokens).returns(100, 150)

        result = @executor.execute(step, is_last_step: true)

        assert_equal "result", result
      end

      test "reports token consumption after successful execution" do
        @base_executor.stubs(:execute).returns("result")
        @context_manager.stubs(:total_tokens).returns(100, 250)

        @executor.execute("test_step")

        assert_equal "✓ Complete: test_step (consumed 150 tokens, total 250)\n\n\n", @output.string
      end

      test "handles nil context manager gracefully" do
        @workflow.stubs(:context_manager).returns(nil)
        @base_executor.stubs(:execute).returns("result")

        @executor.execute("test_step")

        assert_equal "✓ Complete: test_step (consumed 0 tokens, total 0)\n\n\n", @output.string
      end

      test "does not report on execution failure" do
        @base_executor.stubs(:execute).raises(Roast::Error.new("failed"))
        @context_manager.stubs(:total_tokens).returns(100)

        assert_raises(Roast::Error) do
          @executor.execute("failing_step")
        end

        assert_equal "", @output.string
      end

      test "executes multiple steps with reporting" do
        # Test that execute_steps works and reports for each step
        steps = ["step1", "step2"]

        @base_executor.expects(:execute).with("step1", is_last_step: false).returns("result1")
        @base_executor.expects(:execute).with("step2", is_last_step: true).returns("result2")
        @context_manager.stubs(:total_tokens).returns(0, 50, 50, 100)
        @workflow.stubs(:pause_step_name).returns(nil)

        @executor.execute_steps(steps)

        output_lines = @output.string.split("\n")
        assert_match(/✓ Complete: step1 \(consumed 50 tokens, total 50\)/, output_lines[0])
        assert_match(/✓ Complete: step2 \(consumed 50 tokens, total 100\)/, output_lines[3])
      end

      test "extracts step type and uses appropriate name extractor" do
        hash_step = { "analyze" => "Analyze this" }

        # Mock the step type resolution
        StepTypeResolver.expects(:resolve).with(hash_step, @context).returns(StepTypeResolver::HASH_STEP)

        @base_executor.stubs(:execute).returns("result")
        @context_manager.stubs(:total_tokens).returns(100, 200)

        @executor.execute(hash_step)

        assert_match(/✓ Complete: analyze/, @output.string)
      end
    end
  end
end
