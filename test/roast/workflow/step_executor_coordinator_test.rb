# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepExecutorCoordinatorTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:verbose).returns(false)

        @config_hash = {}

        @context = mock("context")
        @context.stubs(:workflow).returns(@workflow)
        @context.stubs(:has_resource?).returns(false)
        @context.stubs(:resource_type).returns(nil) # Changed from :file to nil
        @context.stubs(:config_hash).returns(@config_hash)
        @context.stubs(:context_path).returns("/test/path")
        # Default behavior for exit_on_error?
        @context.stubs(:exit_on_error?).returns(true)

        @dependencies = {
          workflow_executor: mock("workflow_executor"),
          interpolator: mock("interpolator"),
          command_executor: mock("command_executor"),
          iteration_executor: mock("iteration_executor"),
          conditional_executor: mock("conditional_executor"),
          step_loader: mock("step_loader"),
          state_manager: mock("state_manager"),
          error_handler: mock("error_handler"),
        }
        @coordinator = StepExecutorCoordinator.new(context: @context, dependencies: @dependencies)
      end

      def test_executes_command_step
        step = "$(echo hello)"
        # Now command steps go through interpolation
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        # The error handler wraps the execution
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: nil).yields.returns("hello")
        # CommandExecutor expects the full command and strips it internally
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: true).returns("hello")
        # Expect transcript interaction (called twice - once to read, once to append)
        transcript = []
        @workflow.expects(:transcript).returns(transcript).twice

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
        # Configure exit_on_error? to return true for both step names
        @context.stubs(:exit_on_error?).with("nested").returns(true)
        @context.stubs(:exit_on_error?).with("command").returns(true)

        @dependencies[:interpolator].expects(:interpolate).with("var1").returns("var1")
        # Now the coordinator handles this internally by calling execute_steps
        # Which will call execute on the nested hash
        @dependencies[:interpolator].expects(:interpolate).with("nested").returns("nested")
        @dependencies[:interpolator].expects(:interpolate).with("command").returns("command")
        # And then the string step handler will also interpolate
        @dependencies[:interpolator].expects(:interpolate).with("command").returns("command")
        @dependencies[:error_handler].expects(:with_error_handling).with("command", resource_type: nil).yields.returns("result")
        step_object = mock("step")
        step_object.expects(:call).returns("result")
        @dependencies[:step_loader].expects(:load).with("command", exit_on_error: true, step_key: "nested", is_last_step: true).returns(step_object)
        @dependencies[:state_manager].expects(:save_state).with("command", "result")
        @workflow.output.expects(:[]=).with("nested", "result").twice

        @coordinator.execute(step)
      end

      def test_executes_hash_step_with_string_command
        step = { "var1" => "command1" }
        # Configure exit_on_error? to return true for both step names
        @context.stubs(:exit_on_error?).with("var1").returns(true)
        @context.stubs(:exit_on_error?).with("command1").returns(true)

        @dependencies[:interpolator].expects(:interpolate).with("var1").returns("var1")
        @dependencies[:interpolator].expects(:interpolate).with("command1").returns("command1")
        # The string step handler will also try to interpolate, so expect it twice
        @dependencies[:interpolator].expects(:interpolate).with("command1").returns("command1")
        @dependencies[:error_handler].expects(:with_error_handling).with("command1", resource_type: nil).yields.returns("result")
        step_object = mock("step")
        step_object.expects(:call).returns("result")
        @dependencies[:step_loader].expects(:load).with("command1", exit_on_error: true, step_key: "var1", is_last_step: nil).returns(step_object)
        @dependencies[:state_manager].expects(:save_state).with("command1", "result")
        @workflow.output.expects(:[]=).with("var1", "result").twice

        @coordinator.execute(step)
        # Hash steps don't return a value, they set the output
      end

      def test_executes_parallel_step
        steps = ["step1", "step2"]
        # Configure exit_on_error? to return true for both step names
        @context.stubs(:exit_on_error?).with("step1").returns(true)
        @context.stubs(:exit_on_error?).with("step2").returns(true)

        # The new approach uses the factory, which will instantiate ParallelStepExecutor
        # ParallelStepExecutor needs workflow_executor.workflow and workflow_executor.config_hash
        @dependencies[:workflow_executor].stubs(:workflow).returns(@workflow)
        @dependencies[:workflow_executor].stubs(:config_hash).returns({})
        @dependencies[:workflow_executor].stubs(:step_executor_coordinator).returns(@coordinator)
        # When parallel executor runs, it will execute_steps on each item
        # Which goes through the full flow for string steps
        @workflow.stubs(:pause_step_name).returns(nil)
        @dependencies[:interpolator].expects(:interpolate).with("step1").returns("step1")
        @dependencies[:interpolator].expects(:interpolate).with("step2").returns("step2")
        @dependencies[:error_handler].expects(:with_error_handling).with("step1", resource_type: nil).yields
        @dependencies[:error_handler].expects(:with_error_handling).with("step2", resource_type: nil).yields
        step_object1 = mock("step1")
        step_object1.expects(:call).returns("result1")
        step_object2 = mock("step2")
        step_object2.expects(:call).returns("result2")
        @dependencies[:step_loader].expects(:load).with("step1", exit_on_error: true, step_key: "step1", is_last_step: true).returns(step_object1)
        @dependencies[:step_loader].expects(:load).with("step2", exit_on_error: true, step_key: "step2", is_last_step: true).returns(step_object2)
        @dependencies[:state_manager].expects(:save_state).with("step1", "result1")
        @dependencies[:state_manager].expects(:save_state).with("step2", "result2")
        @workflow.output.expects(:[]=).with("step1", "result1")
        @workflow.output.expects(:[]=).with("step2", "result2")

        @coordinator.execute(steps)
      end

      def test_executes_string_step_command
        step = "$(echo test)"
        # Command steps now go through interpolation first
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: nil).yields
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: true).returns("test")
        # Expect transcript interaction (called twice - once to read, once to append)
        transcript = []
        @workflow.expects(:transcript).returns(transcript).twice

        @coordinator.execute(step)
      end

      def test_executes_string_step_regular
        step = "regular_step"
        # Configure exit_on_error? to return false for this step
        @context.stubs(:exit_on_error?).with("regular_step").returns(false)

        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: nil).yields
        step_object = mock("step")
        step_object.expects(:call).returns("result")
        @dependencies[:step_loader].expects(:load).with(step, exit_on_error: false, step_key: step, is_last_step: nil).returns(step_object)
        @dependencies[:state_manager].expects(:save_state).with(step, "result")
        @workflow.output.expects(:[]=).with(step, "result")

        @coordinator.execute(step)
      end

      def test_executes_standard_step_as_fallback
        step = mock("unknown_step")
        @dependencies[:error_handler].expects(:with_error_handling).with(step, resource_type: nil).yields
        step_object = mock("step")
        step_object.expects(:call).returns("result")
        @dependencies[:step_loader].expects(:load).with(step, exit_on_error: true, step_key: step, is_last_step: nil).returns(step_object)
        @dependencies[:state_manager].expects(:save_state).with(step, "result")
        @workflow.output.expects(:[]=).with(step, "result")

        @coordinator.execute(step)
      end

      def test_respects_exit_on_error_option
        step = "$(fail)"
        # Command steps go through interpolation
        @dependencies[:interpolator].expects(:interpolate).with(step).returns(step)
        @dependencies[:error_handler].expects(:with_error_handling).yields
        @dependencies[:command_executor].expects(:execute).with(step, exit_on_error: false)
        # Expect transcript interaction (called twice - once to read, once to append)
        transcript = []
        @workflow.expects(:transcript).returns(transcript).twice

        @coordinator.execute(step, exit_on_error: false)
      end
    end
  end
end
