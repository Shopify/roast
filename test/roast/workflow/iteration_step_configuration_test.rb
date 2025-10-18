# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class IterationStepConfigurationTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:transcript).returns([])
        @workflow.stubs(:model).returns(nil)
        @context_path = "/tmp/test"
        @state_manager = mock("state_manager")
        @state_manager.stubs(:save_state)
        @executor = IterationExecutor.new(@workflow, @context_path, @state_manager, {})
      end

      test "repeat step accepts configuration for model" do
        repeat_config = {
          "repeat" => "repeat",
          "until" => "done",
          "steps" => ["test step"],
          "model" => "gpt-4o",
          "print_response" => true,
          "json" => true,
          "params" => { "temperature" => 0.5 },
        }

        # Mock the RepeatStep to verify configuration was applied
        mock_step = mock("repeat_step")
        mock_step.expects(:model=).with("gpt-4o")
        mock_step.expects(:print_response=).with(true)
        mock_step.expects(:json=).with(true)
        mock_step.expects(:params=).with({ "temperature" => 0.5 })
        mock_step.expects(:call).returns("result")

        RepeatStep.expects(:new).with(
          @workflow,
          steps: ["test step"],
          until_condition: "done",
          max_iterations: 100,
          name: "repeat_0",
          context_path: @context_path,
          config_hash: {},
        ).returns(mock_step)

        @executor.execute_repeat(repeat_config)
      end

      test "each step accepts configuration for model" do
        each_config = {
          "each" => "[1, 2, 3]",
          "as" => "item",
          "steps" => ["process item"],
          "model" => "claude-opus",
          "print_response" => false,
        }

        # Mock the EachStep to verify configuration was applied
        mock_step = mock("each_step")
        mock_step.expects(:model=).with("claude-opus")
        mock_step.expects(:print_response=).with(false)
        mock_step.expects(:call).returns("result")

        EachStep.expects(:new).with(
          @workflow,
          collection_expr: "[1, 2, 3]",
          variable_name: "item",
          steps: ["process item"],
          name: "each_item",
          context_path: @context_path,
          config_hash: {},
        ).returns(mock_step)

        @executor.execute_each(each_config)
      end

      test "configuration is optional for iterator steps" do
        # Test that steps work without configuration
        repeat_config = {
          "repeat" => "repeat",
          "until" => "done",
          "steps" => ["test step"],
        }

        RepeatStep.any_instance.expects(:call).returns("result")

        assert_nothing_raised do
          @executor.execute_repeat(repeat_config)
        end
      end
    end
  end
end
