# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class RetryTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:transcript).returns([])
        @workflow.stubs(:verbose).returns(false)
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:pause_step_name).returns(nil)

        @config_hash = {}
        @context_path = "/test/path"

        @context = WorkflowContext.new(
          workflow: @workflow,
          config_hash: @config_hash,
          context_path: @context_path,
        )

        @error_handler = mock("error_handler")
        @command_executor = mock("command_executor")
        @interpolator = mock("interpolator")
        @state_manager = mock("state_manager")
        @step_loader = mock("step_loader")

        @coordinator = StepExecutorCoordinator.new(
          context: @context,
          dependencies: {
            workflow_executor: mock("workflow_executor"),
            interpolator: @interpolator,
            command_executor: @command_executor,
            error_handler: @error_handler,
            step_loader: @step_loader,
            state_manager: @state_manager,
          },
        )
      end

      test "retries custom step when configured" do
        step_name = "test_step"
        @config_hash[step_name] = { "retries" => 2 }

        step_object = mock("step_object")
        @step_loader.expects(:load).times(3).returns(step_object)

        # First two calls fail, third succeeds
        step_object.expects(:call).times(3).raises(StandardError.new("Test error")).then.raises(StandardError.new("Test error")).then.returns("success")

        @error_handler.expects(:with_error_handling).times(3).yields
        @state_manager.expects(:save_state).with(step_name, "success")

        result = @coordinator.send(:execute_custom_step, step_name)
        assert_equal "success", result
        assert_equal "success", @workflow.output[step_name]
      end

      test "stops retrying after exhausting retry count" do
        step_name = "test_step"
        @config_hash[step_name] = { "retries" => 1 }

        step_object = mock("step_object")
        @step_loader.expects(:load).times(2).returns(step_object)

        # Both attempts fail
        step_object.expects(:call).times(2).raises(StandardError.new("Test error"))

        @error_handler.expects(:with_error_handling).times(2).yields
        @state_manager.expects(:save_state).never

        assert_raises(StandardError) do
          @coordinator.send(:execute_custom_step, step_name)
        end
      end

      test "does not retry when exit_on_error is false" do
        step_name = "test_step"
        @config_hash[step_name] = { "retries" => 3, "exit_on_error" => false }

        step_object = mock("step_object")
        @step_loader.expects(:load).once.returns(step_object)

        # Single attempt that fails
        step_object.expects(:call).once.raises(StandardError.new("Test error"))

        @error_handler.expects(:with_error_handling).once.yields
        @state_manager.expects(:save_state).never

        assert_raises(StandardError) do
          @coordinator.send(:execute_custom_step, step_name)
        end
      end

      test "retries command step when configured" do
        command = "$(echo test)"
        step_name = "test_command"
        @config_hash[step_name] = { "retries" => 2 }

        # First two executions fail, third succeeds
        error = CommandExecutor::CommandExecutionError.new("Command failed", command: command, exit_status: 1)
        @command_executor.expects(:execute).times(3)
          .raises(error)
          .then.raises(error)
          .then.returns("success")

        @error_handler.expects(:with_error_handling).times(3).yields

        result = @coordinator.send(:execute_command_step, command, { exit_on_error: true, step_key: step_name })
        assert_equal "success", result
      end

      test "does not retry command when exit_on_error is false" do
        command = "$(echo test)"
        step_name = "test_command"
        @config_hash[step_name] = { "retries" => 3 }

        error = CommandExecutor::CommandExecutionError.new("Command failed", command: command, exit_status: 1)
        @command_executor.expects(:execute).once.raises(error)
        @error_handler.expects(:with_error_handling).once.yields

        assert_raises(CommandExecutor::CommandExecutionError) do
          @coordinator.send(:execute_command_step, command, { exit_on_error: false, step_key: step_name })
        end
      end

      test "get_retry_count returns 0 when no retries configured" do
        assert_equal 0, @coordinator.send(:get_retry_count, "unconfigured_step")
      end

      test "get_retry_count returns configured value" do
        @config_hash["step_with_retries"] = { "retries" => 5 }
        assert_equal 5, @coordinator.send(:get_retry_count, "step_with_retries")
      end

      test "get_retry_count handles string values" do
        @config_hash["step_with_string_retries"] = { "retries" => "3" }
        assert_equal 3, @coordinator.send(:get_retry_count, "step_with_string_retries")
      end

      test "get_retry_count returns 0 for non-hash config" do
        @config_hash["string_step"] = "some_value"
        assert_equal 0, @coordinator.send(:get_retry_count, "string_step")
      end
    end
  end
end
