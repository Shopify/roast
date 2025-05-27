# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_executor_coordinator"
require "roast/workflow/workflow_context"

module Roast
  module Workflow
    class StepExecutorCoordinatorTest < Minitest::Test
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:transcript).returns([])
        @workflow.stubs(:output).returns({})

        @context = mock("context")
        @context.stubs(:workflow).returns(@workflow)
        @context.stubs(:has_resource?).returns(false)
        @context.stubs(:resource_type).returns(:file)

        @dependencies = {
          workflow_executor: mock("workflow_executor"),
          interpolator: mock("interpolator"),
          command_executor: mock("command_executor"),
          iteration_executor: mock("iteration_executor"),
          step_orchestrator: mock("step_orchestrator"),
          error_handler: mock("error_handler"),
        }

        @coordinator = StepExecutorCoordinator.new(
          context: @context,
          dependencies: @dependencies,
        )
      end

      def test_executes_command_step
        step = "$(echo hello)"
        # Now command steps go through interpolation
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        # The error handler wraps the execution
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: :file).yields.returns("hello")
        # CommandExecutor expects the full command and strips it internally
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: true).returns("hello")

        result = @coordinator.execute(step)
        assert_equal("hello", result)
      end

      def test_executes_glob_step
        step = "*.rb"
        Dir.expects(:glob).with(step).returns(["file1.rb", "file2.rb"])

        result = @coordinator.execute(step)
        assert_equal("file1.rb\nfile2.rb", result)
      end

      def test_executes_iteration_step_repeat
        step = { "repeat" => { "until" => "done" } }
        @dependencies[:iteration_executor].expects(:execute_repeat).with({ "until" => "done" })

        @coordinator.execute(step)
      end

      def test_executes_iteration_step_each
        step = { "each" => "items", "as" => "item", "steps" => ["process"] }
        @dependencies[:iteration_executor].expects(:execute_each).with(step)

        @coordinator.execute(step)
      end

      def test_validates_each_step_format
        step = { "each" => "items" } # Missing 'as' and 'steps'

        error = assert_raises(WorkflowExecutor::ConfigurationError) do
          @coordinator.execute(step)
        end

        assert_match(/Invalid 'each' step format/, error.message)
      end

      def test_executes_hash_step_with_hash_command
        step = { "var1" => { "nested" => "command" } }
        @dependencies[:interpolator].expects(:interpolate).with("var1").returns("var1")
        @dependencies[:workflow_executor].expects(:execute_steps).with([{ "nested" => "command" }])

        @coordinator.execute(step)
      end

      def test_executes_hash_step_with_string_command
        step = { "var1" => "command1" }
        @dependencies[:interpolator].expects(:interpolate).with("var1").returns("var1")
        @dependencies[:interpolator].expects(:interpolate).with("command1").returns("command1")
        @context.expects(:exit_on_error?).with("var1").returns(true)
        # The string step handler will also try to interpolate, so expect it twice
        @dependencies[:interpolator].expects(:interpolate).with("command1").returns("command1")
        @context.expects(:exit_on_error?).with("command1").returns(true)
        @dependencies[:step_orchestrator].expects(:execute_step).with("command1", exit_on_error: true).returns("result")

        @workflow.output.expects(:[]=).with("var1", "result")

        @coordinator.execute(step)
        # Hash steps don't return a value, they set the output
      end

      def test_executes_parallel_step
        steps = ["step1", "step2"]
        # The new approach uses the factory, which will instantiate ParallelStepExecutor
        # ParallelStepExecutor needs workflow_executor.workflow and workflow_executor.config_hash
        @dependencies[:workflow_executor].stubs(:workflow).returns(@workflow)
        @dependencies[:workflow_executor].stubs(:config_hash).returns({})
        @dependencies[:workflow_executor].expects(:execute_steps).with(["step1"])
        @dependencies[:workflow_executor].expects(:execute_steps).with(["step2"])

        @coordinator.execute(steps)
      end

      def test_executes_string_step_command
        step = "$(echo test)"
        # Command steps now go through interpolation first
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: :file).yields
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: true).returns("test")

        @coordinator.execute(step)
      end

      def test_executes_string_step_regular
        step = "regular_step"
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @context.expects(:exit_on_error?).with(step).returns(false)
        @dependencies[:step_orchestrator].expects(:execute_step).with(step, exit_on_error: false)

        @coordinator.execute(step)
      end

      def test_executes_standard_step_as_fallback
        step = mock("unknown_step")
        @dependencies[:step_orchestrator].expects(:execute_step).with(step, exit_on_error: true)

        @coordinator.execute(step)
      end

      def test_respects_exit_on_error_option
        step = "$(fail)"
        # Command steps go through interpolation
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @dependencies[:error_handler].expects(:with_error_handling).yields
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: false)

        @coordinator.execute(step, exit_on_error: false)
      end
    end
  end
end
