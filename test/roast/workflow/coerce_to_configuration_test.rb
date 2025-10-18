# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class CoerceToConfigurationTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:name).returns("test_workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:transcript).returns([])
        @workflow.stubs(:resource).returns(nil)
        @workflow.stubs(:append_to_final_output)
        @workflow.stubs(:openai?).returns(false)
        @workflow.stubs(:pause_step_name).returns(nil)
        @workflow.stubs(:tools).returns(nil)
        @workflow.stubs(:storage_type).returns(nil)
        @workflow.stubs(:model).returns(nil)
      end

      test "step with coerce_to boolean returns boolean for truthy string" do
        config_hash = {
          "check status" => {
            "coerce_to" => "boolean",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        @workflow.expects(:chat_completion).returns("yes, it's working")

        result = executor.execute_step("check status")
        assert_equal true, result
      end

      test "step with coerce_to boolean returns false for empty string" do
        config_hash = {
          "check status" => {
            "coerce_to" => "boolean",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        @workflow.expects(:chat_completion).returns("")

        result = executor.execute_step("check status")
        assert_equal false, result
      end

      test "step with coerce_to llm_boolean uses LLM boolean coercer" do
        config_hash = {
          "is it ready" => {
            "coerce_to" => "llm_boolean",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        @workflow.expects(:chat_completion).returns("Absolutely, it's ready to go!")
        LlmBooleanCoercer.expects(:coerce).with("Absolutely, it's ready to go!").returns(true)

        result = executor.execute_step("is it ready")
        assert_equal true, result
      end

      test "step with coerce_to iterable returns array from string" do
        config_hash = {
          "list files" => {
            "coerce_to" => "iterable",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        @workflow.expects(:chat_completion).returns("file1.txt\nfile2.txt\nfile3.txt")

        result = executor.execute_step("list files")
        assert_equal ["file1.txt", "file2.txt", "file3.txt"], result
      end

      test "step with coerce_to iterable returns array from JSON string" do
        config_hash = {
          "get items" => {
            "coerce_to" => "iterable",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        # Raix 1.0 returns strings, even for JSON
        @workflow.expects(:chat_completion).returns('["item1", "item2", "item3"]')

        result = executor.execute_step("get items")
        assert_equal ["item1", "item2", "item3"], result
      end

      test "step without coerce_to returns result unchanged" do
        config_hash = {
          "get data" => {
            "model" => "gpt-4o",
          },
        }

        executor = WorkflowExecutor.new(@workflow, config_hash, "/tmp/test")

        @workflow.expects(:chat_completion).returns("raw response data")

        result = executor.execute_step("get data")
        assert_equal "raw response data", result
      end

      test "repeat step can use coerce_to llm_boolean" do
        repeat_config = {
          "repeat" => "repeat",
          "until" => "is task complete",
          "steps" => ["work on task"],
          "coerce_to" => "llm_boolean",
        }

        state_manager = mock("state_manager")
        state_manager.stubs(:save_state)
        executor = IterationExecutor.new(@workflow, "/tmp/test", state_manager)

        # Mock the step configuration to have coerce_to
        mock_step = mock("repeat_step")
        mock_step.stubs(:coerce_to=).with(:llm_boolean)
        mock_step.stubs(:model=)
        mock_step.stubs(:print_response=)
        mock_step.stubs(:json=)
        mock_step.stubs(:params=)
        mock_step.expects(:call).returns(["task result"])

        RepeatStep.expects(:new).returns(mock_step)

        result = executor.execute_repeat(repeat_config)
        assert_equal ["task result"], result
      end
    end
  end
end
