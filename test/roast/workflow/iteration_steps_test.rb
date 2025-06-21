# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class IterationStepsTest < ActiveSupport::TestCase
      include FixtureHelpers

      def setup
        @workflow = BaseWorkflow.new(nil, name: "test_workflow")
        @workflow.output = {}
        @context_path = File.expand_path("../../fixtures/steps/iteration_test", __dir__)

        # Create test iteration step for input type testing
        @iteration_step = Class.new(BaseIterationStep) do
          def initialize(workflow, context_path)
            super(workflow, steps: [], name: "test_iteration_step", context_path: context_path)
          end

          def test_input(input, context, coerce_to: nil)
            process_iteration_input(input, context, coerce_to: coerce_to)
          end
        end.new(@workflow, @context_path)
      end

      def test_repeat_step_with_condition_met
        # Create a repeat step that will terminate after condition is met
        repeat_step = RepeatStep.new(
          @workflow,
          steps: ["increment_counter", "check_counter"],
          until_condition: "{{output['condition_met'] == true}}",
          max_iterations: 10,
          name: "repeat_until_condition_met",
          context_path: @context_path,
        )

        # Execute the repeat step
        repeat_step.call

        # Verify the step executed until the condition was met (3 iterations)
        assert_equal(3, @workflow.output["counter"])
        assert_equal(true, @workflow.output["condition_met"])
      end

      def test_repeat_step_with_max_iterations_reached
        # Create a repeat step with a condition that won't be met
        repeat_step = RepeatStep.new(
          @workflow,
          steps: ["infinite_step"],
          until_condition: "{{false}}", # Never satisfied
          max_iterations: 5,            # But limited to 5 iterations
          name: "repeat_with_limit",
          context_path: @context_path,
        )

        # Execute the repeat step
        repeat_step.call

        # Verify the step executed the maximum number of times
        assert_equal(5, @workflow.output["execution_count"])
      end

      def test_each_step
        # Setup test data
        @workflow.output["test_items"] = [1, 2, 3, 4, 5]

        # Add the getter method for current_item that our test steps expect
        class << @workflow
          attr_reader :current_item
        end

        # Create an each step
        each_step = EachStep.new(
          @workflow,
          collection_expr: "{{output['test_items']}}",
          variable_name: "current_item",
          steps: ["process_item"],
          name: "each_item",
          context_path: @context_path,
        )

        # Execute the each step
        each_step.call

        # Verify each item was processed
        assert_equal([1, 2, 3, 4, 5], @workflow.output["processed_items"])
      end

      def test_each_step_with_empty_collection
        # Setup an empty collection
        @workflow.output["empty_items"] = []

        # Add the getter method for current_item that our test steps expect
        class << @workflow
          attr_reader :current_item
        end

        # Flag to track if any steps were executed
        @workflow.output["steps_executed"] = false

        # Create a step that will set the flag if executed
        def @workflow.would_fail_if_executed
          # This should never be called for an empty collection
          @output["steps_executed"] = true
          "This step should not be executed"
        end

        # Create an each step with an empty collection
        each_step = EachStep.new(
          @workflow,
          collection_expr: "{{output['empty_items']}}",
          variable_name: "current_item",
          steps: ["would_fail_if_executed"],
          name: "each_empty",
          context_path: @context_path,
        )

        # Execute the each step
        results = each_step.call

        # Verify no steps were executed
        assert_equal(false, @workflow.output["steps_executed"])
        assert_equal(0, results.size)
      end

      # Tests for different input types in iteration constructs

      def test_ruby_expression_input
        # Test with boolean coercion
        @workflow.output["test_value"] = 42
        result = @iteration_step.test_input("{{output['test_value'] > 40}}", @workflow, coerce_to: :boolean)
        assert_equal(true, result)

        # Test with iterable coercion
        result = @iteration_step.test_input("{{[1, 2, 3]}}", @workflow, coerce_to: :iterable)
        assert_equal([1, 2, 3], result)
      end

      def test_bash_command_input
        # Mock execute_command to return predictable values without redefinition warnings
        @iteration_step.stubs(:execute_command).with("exit 0", :boolean).returns(true)
        @iteration_step.stubs(:execute_command).with("exit 1", :boolean).returns(false)
        @iteration_step.stubs(:execute_command).with("echo 'line1\nline2\nline3'", :iterable).returns(["line1", "line2", "line3"])

        # Test bash command with boolean coercion (exitcode 0 = true)
        result = @iteration_step.test_input("$(exit 0)", @workflow, coerce_to: :boolean)
        assert_equal(true, result)

        # Test bash command with boolean coercion (exitcode 1 = false)
        result = @iteration_step.test_input("$(exit 1)", @workflow, coerce_to: :boolean)
        assert_equal(false, result)

        # Test bash command with iterable output
        result = @iteration_step.test_input("$(echo 'line1\nline2\nline3')", @workflow, coerce_to: :iterable)
        assert_equal(["line1", "line2", "line3"], result)
      end

      def test_step_handling
        # For step handling, we'll mock the execute_step_by_name method
        # since it's hard to set up actual steps in tests
        @iteration_step.stubs(:execute_step_by_name).with("test_boolean_step", @workflow).returns(true)
        @iteration_step.stubs(:execute_step_by_name).with("test_iterable_step", @workflow).returns([4, 5, 6])

        # Test step name with boolean coercion
        result = @iteration_step.test_input("test_boolean_step", @workflow, coerce_to: :boolean)
        assert_equal(true, result)

        # Test step name with iterable coercion
        result = @iteration_step.test_input("test_iterable_step", @workflow, coerce_to: :iterable)
        assert_equal([4, 5, 6], result)
      end

      def test_direct_value_input
        # For direct value input, we'll mock the process_step_or_prompt method
        # to bypass the step execution
        @iteration_step.stubs(:process_step_or_prompt).with(true, @workflow, :boolean).returns(true)
        @iteration_step.stubs(:process_step_or_prompt).with(nil, @workflow, :boolean).returns(false)
        @iteration_step.stubs(:process_step_or_prompt).with([1, 2], @workflow, :iterable).returns([1, 2])
        @iteration_step.stubs(:process_step_or_prompt).with("test", @workflow, :iterable).returns(["test"])

        # Test direct values with boolean coercion
        assert_equal(true, @iteration_step.test_input(true, @workflow, coerce_to: :boolean))
        assert_equal(false, @iteration_step.test_input(nil, @workflow, coerce_to: :boolean))

        # Test direct values with iterable coercion
        assert_equal([1, 2], @iteration_step.test_input([1, 2], @workflow, coerce_to: :iterable))
        # With a string value, it should be split into lines
        assert_equal(["test"], @iteration_step.test_input("test", @workflow, coerce_to: :iterable))
      end

      def test_llm_boolean_coercion
        # Test explicit boolean responses
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "yes"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "Yes"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "YES"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "y"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "true"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "t"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "1"))

        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "no"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "No"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "NO"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "n"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "false"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "f"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "0"))

        # Test boolean values
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, true))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, false))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, nil))

        # Test affirmative words in longer responses
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "I think the answer is yes"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "That is correct"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "Absolutely right"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "I agree with that"))
        assert_equal(true, @iteration_step.send(:coerce_to_llm_boolean, "That is definitely true"))

        # Test negative words in longer responses
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "I disagree with that statement"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "That is incorrect"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "I disagree"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "That's wrong"))
        assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "Never"))

        # Test ambiguous responses (should default to false)
        assert_output(nil, /Ambiguous LLM response.*contains both affirmative and negative/) do
          assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "Yes, but actually no"))
        end

        assert_output(nil, /Ambiguous LLM response.*no clear boolean indicators/) do
          assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "Maybe"))
        end

        assert_output(nil, /Ambiguous LLM response.*no clear boolean indicators/) do
          assert_equal(false, @iteration_step.send(:coerce_to_llm_boolean, "I'm not sure"))
        end
      end
    end
  end
end
