# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ErrorHandlerRetryTest < ActiveSupport::TestCase
      def setup
        @retry_coordinator = mock("retry_coordinator")
        @error_handler = ErrorHandler.new(retry_coordinator: @retry_coordinator)
      end

      test "uses retry coordinator when step config provided" do
        step_config = { "retry" => { "max_attempts" => 3 } }

        @retry_coordinator.expects(:execute_with_retry).with(step_config).yields.returns("success")

        result = @error_handler.with_error_handling("test_step", step_config: step_config) do
          "success"
        end

        assert_equal "success", result
      end

      test "executes directly when no step config" do
        @retry_coordinator.expects(:execute_with_retry).never

        result = @error_handler.with_error_handling("test_step") do
          "success"
        end

        assert_equal "success", result
      end

      test "executes directly when step config is nil" do
        @retry_coordinator.expects(:execute_with_retry).never

        result = @error_handler.with_error_handling("test_step", step_config: nil) do
          "success"
        end

        assert_equal "success", result
      end

      test "passes resource type through retry" do
        step_config = { "retry" => 2 }
        events = []

        @retry_coordinator.expects(:execute_with_retry).with(step_config).yields.returns("success")

        ActiveSupport::Notifications.subscribe("roast.step.start") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event.payload
        end

        @error_handler.with_error_handling(
          "test_step",
          resource_type: "file",
          step_config: step_config,
        ) do
          "success"
        end

        assert_equal(1, events.size)
        assert_equal("test_step", events[0][:step_name])
        assert_equal("file", events[0][:resource_type])
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.step.start")
      end

      test "maintains error handling behavior with retry" do
        step_config = { "retry" => 1 }

        # Make retry coordinator pass through the error by just yielding
        @retry_coordinator.expects(:execute_with_retry).with(step_config).yields

        assert_raises(WorkflowExecutor::StepExecutionError) do
          @error_handler.with_error_handling("test_step", step_config: step_config) do
            raise StandardError, "test error"
          end
        end
      end
    end
  end
end
