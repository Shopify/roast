# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class IterationConfigHashTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:model).returns(nil)
        @state_manager = mock("state_manager")
        @state_manager.stubs(:save_state)

        @config_hash = {
          "model" => "gpt-4o",
          "nested_step" => {
            "model" => "gpt-3.5-turbo",
          },
        }
      end

      test "IterationExecutor passes config_hash to RepeatStep" do
        executor = IterationExecutor.new(@workflow, "/test/path", @state_manager, @config_hash)

        repeat_config = {
          "until" => "true",
          "steps" => ["nested_step"],
          "model" => "claude-3-opus-20240229",
        }

        # Mock RepeatStep to verify it receives config_hash
        repeat_step_mock = mock("repeat_step")
        repeat_step_mock.stubs(:model=)
        repeat_step_mock.expects(:call).returns("result")

        RepeatStep.expects(:new).with do |workflow, params|
          workflow == @workflow &&
            params[:config_hash] == @config_hash &&
            params[:steps] == ["nested_step"]
        end.returns(repeat_step_mock)

        executor.execute_repeat(repeat_config)
      end

      test "IterationExecutor passes config_hash to EachStep" do
        executor = IterationExecutor.new(@workflow, "/test/path", @state_manager, @config_hash)

        each_config = {
          "each" => "[1, 2]",
          "as" => "item",
          "steps" => ["process_item"],
          "model" => "claude-3-haiku-20240307",
        }

        # Mock EachStep to verify it receives config_hash
        each_step_mock = mock("each_step")
        each_step_mock.stubs(:model=)
        each_step_mock.expects(:call).returns("result")

        EachStep.expects(:new).with do |workflow, params|
          workflow == @workflow &&
            params[:config_hash] == @config_hash &&
            params[:steps] == ["process_item"]
        end.returns(each_step_mock)

        executor.execute_each(each_config)
      end

      test "BaseIterationStep creates WorkflowExecutor with config_hash" do
        # Create a test subclass to access protected methods
        test_step = Class.new(BaseIterationStep) do
          def test_execute_nested_steps(steps, context)
            execute_nested_steps(steps, context)
          end

          def test_execute_step_by_name(step_name, context)
            execute_step_by_name(step_name, context)
          end
        end.new(
          @workflow,
          steps: ["step1"],
          config_hash: @config_hash,
          context_path: "/test/path",
          name: "test_iteration",
        )

        # Mock WorkflowExecutor to verify it receives config_hash
        executor_mock = mock("executor")
        executor_mock.stubs(:execute_step).returns("result")
        executor_mock.stubs(:execute_steps).returns(["result"])

        WorkflowExecutor.expects(:new).with(@workflow, @config_hash, "/test/path").returns(executor_mock)

        test_step.test_execute_nested_steps(["step1"], @workflow)
      end

      test "BaseIterationStep execute_step_by_name creates WorkflowExecutor with config_hash" do
        test_step = Class.new(BaseIterationStep) do
          def test_execute_step_by_name(step_name, context)
            execute_step_by_name(step_name, context)
          end
        end.new(
          @workflow,
          steps: ["step1"],
          config_hash: @config_hash,
          context_path: "/test/path",
          name: "test_iteration",
        )

        # Mock WorkflowExecutor to verify it receives config_hash
        WorkflowExecutor.expects(:new).with(@workflow, @config_hash, "/test/path").returns(
          mock("executor", execute_step: "result"),
        )

        test_step.test_execute_step_by_name("test_step", @workflow)
      end
    end
  end
end
