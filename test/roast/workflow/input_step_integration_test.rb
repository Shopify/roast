# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InputStepIntegrationTest < ActiveSupport::TestCase
      test "StepTypeResolver recognizes input steps" do
        input_step = { "input" => { "prompt" => "Enter value:" } }

        assert StepTypeResolver.input_step?(input_step)
        assert_equal StepTypeResolver::INPUT_STEP, StepTypeResolver.resolve(input_step)
      end

      test "StepTypeResolver does not recognize non-input hash steps as input" do
        other_steps = [
          { "regular_step" => "value" },
          { "if" => { "condition" => true } },
          { "case" => { "expression" => "value" } },
        ]

        other_steps.each do |step|
          assert_not StepTypeResolver.input_step?(step)
          assert_not_equal StepTypeResolver::INPUT_STEP, StepTypeResolver.resolve(step)
        end
      end

      test "StepExecutorCoordinator routes input steps correctly" do
        workflow = mock("workflow")
        workflow.stubs(:metadata).returns({})
        workflow.stubs(:output).returns({})
        workflow.stubs(:pause_step_name).returns(nil)

        context = mock("context")
        context.stubs(:workflow).returns(workflow)
        context.stubs(:context_path).returns("/test")

        state_manager = mock("state_manager")
        state_manager.stubs(:save_state)

        input_executor = mock("input_executor")
        input_executor.expects(:execute_input).with({ "prompt" => "Test?" }).returns("result")

        dependencies = {
          state_manager: state_manager,
          input_executor: input_executor,
        }

        coordinator = StepExecutorCoordinator.new(context: context, dependencies: dependencies)

        input_step = { "input" => { "prompt" => "Test?" } }
        result = coordinator.execute(input_step)

        assert_equal "result", result
      end
    end
  end
end
