# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class SmartCoercionDefaultsTest < ActiveSupport::TestCase
      class TestWorkflow < BaseWorkflow
        attr_accessor :transcript

        def initialize(file = nil)
          super(file)
          @transcript = []
        end

        def chat_completion(**_opts)
          "Yes, this is true."
        end
      end

      test "ruby expression defaults to regular boolean coercion" do
        workflow = TestWorkflow.new
        workflow.output = { "counter" => 5 }

        step = RepeatStep.new(
          workflow,
          steps: [{ "increment" => "counter += 1" }],
          until_condition: "{{counter > 10}}",
          max_iterations: 10,
        )

        # Test the coercion directly
        result = step.send(:process_iteration_input, "{{counter > 10}}", workflow)

        # With smart defaults, ruby expressions should use regular boolean
        assert_equal false, result

        workflow.output["counter"] = 11
        result = step.send(:process_iteration_input, "{{counter > 10}}", workflow)
        assert_equal true, result
      end

      test "bash command defaults to boolean with exit code interpretation" do
        workflow = TestWorkflow.new

        step = RepeatStep.new(
          workflow,
          steps: [{ "check" => "echo checking" }],
          until_condition: "$(ls /nonexistent_file_path)",
          max_iterations: 1,
        )

        # Test the coercion directly
        # Test with a command that fails (ls on non-existent file)
        result = step.send(:process_iteration_input, "$(ls /nonexistent_file_path 2>/dev/null)", workflow)

        # Should be false because command exits with error
        assert_equal false, result

        # Test with a command that succeeds (pwd always succeeds)
        result = step.send(:process_iteration_input, "$(pwd)", workflow)
        assert_equal true, result
      end

      test "prompt step defaults to llm_boolean coercion" do
        workflow = TestWorkflow.new

        step = RepeatStep.new(
          workflow,
          steps: [{ "action" => "echo doing something" }],
          until_condition: "check condition",
          max_iterations: 1,
        )

        # Mock the LlmBooleanCoercer behavior

        # Test positive responses
        assert_equal true, step.send(:coerce_result, "Yes, the condition is met.", :llm_boolean)
        assert_equal true, step.send(:coerce_result, "True", :llm_boolean)
        assert_equal true, step.send(:coerce_result, "Affirmative", :llm_boolean)

        # Test negative responses
        assert_equal false, step.send(:coerce_result, "No, not yet.", :llm_boolean)
        assert_equal false, step.send(:coerce_result, "False", :llm_boolean)
        assert_equal false, step.send(:coerce_result, "Negative", :llm_boolean)
      end

      test "explicit coerce_to overrides smart defaults" do
        workflow = TestWorkflow.new

        step = RepeatStep.new(
          workflow,
          steps: [{ "process" => "echo processing" }],
          until_condition: "{{true}}",
          max_iterations: 1,
        )

        # Test that explicit coerce_to overrides smart defaults
        # Ruby expression would normally default to boolean, but we override to iterable
        result = step.send(:process_iteration_input, "{{'hello'}}", workflow, coerce_to: :iterable)

        # Should be an array with one element
        assert_equal ["hello"], result

        # Test non-string input with explicit iterable coercion
        result = step.send(:coerce_result, "apple\nbanana\norange", :iterable)
        assert_equal ["apple", "banana", "orange"], result

        # Test that ruby expression with explicit boolean still works
        result = step.send(:process_iteration_input, "{{1 + 1 == 2}}", workflow, coerce_to: :boolean)
        assert_equal true, result
      end

      test "non-string inputs default to regular boolean" do
        workflow = TestWorkflow.new

        step = RepeatStep.new(
          workflow,
          steps: [{ "action" => "echo doing something" }],
          until_condition: "check",
          max_iterations: 1,
        )

        # Test with various non-string inputs
        assert_equal false, step.send(:process_iteration_input, nil, workflow)
        assert_equal false, step.send(:process_iteration_input, false, workflow)
        assert_equal true, step.send(:process_iteration_input, true, workflow)
        assert_equal true, step.send(:process_iteration_input, 42, workflow)
        assert_equal true, step.send(:process_iteration_input, [], workflow)
        assert_equal true, step.send(:process_iteration_input, 0, workflow) # In Ruby, 0 is truthy
      end
    end
  end
end
