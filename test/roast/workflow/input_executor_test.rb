# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InputExecutorTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:model).returns(nil)
        @context_path = "/test/context"
        @state_manager = mock("state_manager")
        @workflow_executor = mock("workflow_executor")

        @executor = InputExecutor.new(@workflow, @context_path, @state_manager, @workflow_executor)
      end

      test "executes input step with name" do
        input_config = {
          "prompt" => "Enter your name:",
          "name" => "user_name",
        }

        # Mock interpolation
        @workflow_executor.expects(:interpolate).with("Enter your name:").returns("Enter your name:")

        # Mock InputStep behavior
        InputStep.any_instance.expects(:call).returns("John Doe")
        @state_manager.expects(:save_state).with("previous", "John Doe")

        result = @executor.execute_input(input_config)

        assert_equal "John Doe", result
        assert_equal "John Doe", @workflow.output["previous"]
      end

      test "executes input step without name" do
        input_config = {
          "prompt" => "Press enter to continue",
        }

        # Mock interpolation
        @workflow_executor.expects(:interpolate).with("Press enter to continue").returns("Press enter to continue")

        # Mock InputStep behavior
        InputStep.any_instance.expects(:call).returns("")
        @state_manager.expects(:save_state).with("previous", "")

        result = @executor.execute_input(input_config)

        assert_equal "", result
        assert_equal "", @workflow.output["previous"]
        assert_nil @workflow.output["input_"] # Should not store without name
      end

      test "executes input step successfully" do
        input_config = {
          "prompt" => "Enter value:",
          "name" => "test_value",
        }

        # Mock interpolation
        @workflow_executor.expects(:interpolate).with("Enter value:").returns("Enter value:")

        InputStep.any_instance.expects(:call).returns("test")
        @state_manager.expects(:save_state).with("previous", "test")

        result = @executor.execute_input(input_config)

        assert_equal "test", result
        assert_equal "test", @workflow.output["previous"]
      end

      test "creates InputStep with correct parameters" do
        input_config = {
          "prompt" => "Test prompt",
          "name" => "test_name",
          "type" => "boolean",
        }

        # Mock interpolation
        @workflow_executor.expects(:interpolate).with("Test prompt").returns("Test prompt")
        interpolated_config = input_config.merge("prompt" => "Test prompt")

        InputStep.expects(:new).with(
          @workflow,
          config: interpolated_config,
          name: "test_name",
          context_path: @context_path,
        ).returns(mock(call: true))

        @state_manager.stubs(:save_state)

        @executor.execute_input(input_config)
      end

      test "generates unique name for unnamed inputs" do
        input_config = {
          "prompt" => "Anonymous input",
        }

        # Mock interpolation
        @workflow_executor.expects(:interpolate).with("Anonymous input").returns("Anonymous input")
        interpolated_config = input_config.merge("prompt" => "Anonymous input")

        # Freeze time to ensure consistent naming
        Time.stubs(:now).returns(Time.at(1234567890))

        InputStep.expects(:new).with(
          @workflow,
          config: interpolated_config,
          name: "input_1234567890",
          context_path: @context_path,
        ).returns(mock(call: "result"))

        @state_manager.stubs(:save_state)

        @executor.execute_input(input_config)
      end
    end
  end
end
