# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class CoerceToDirectSyntaxTest < ActiveSupport::TestCase
      class TestWorkflow < BaseWorkflow
        attr_accessor :transcript

        def initialize(file = nil)
          super(file)
          @transcript = []
        end

        def chat_completion(**_opts)
          "Yes, proceed!"
        end
      end

      test "coerce_to can be specified directly in repeat step without config block" do
        workflow = TestWorkflow.new
        context_path = "test"
        state_manager = StateManager.new(workflow)
        executor = IterationExecutor.new(workflow, context_path, state_manager)

        # Direct syntax without config block
        repeat_config = {
          "repeat" => true,
          "until" => "{{true}}",
          "coerce_to" => "boolean", # Direct property
          "steps" => [{ "log" => "processing..." }],
          "max_iterations" => 1,
        }

        result = executor.execute_repeat(repeat_config)

        # Should work with direct syntax
        assert_not_nil result
      end

      test "coerce_to can be specified directly in each step without config block" do
        workflow = TestWorkflow.new

        # Test that the configuration is applied correctly
        each_step = EachStep.new(
          workflow,
          collection_expr: "{{'apple\nbanana\norange'}}",
          variable_name: "item",
          steps: [{ "log" => "{{item}}" }],
        )

        context_path = "test"
        state_manager = StateManager.new(workflow)
        executor = IterationExecutor.new(workflow, context_path, state_manager)

        # Apply config with direct syntax
        config = {
          "coerce_to" => "iterable", # Direct property
        }

        executor.send(:apply_step_configuration, each_step, config)

        # Should have iterable coercion
        assert_equal :iterable, each_step.coerce_to
      end

      test "direct syntax works properly" do
        workflow = TestWorkflow.new

        # Create a repeat step to test coerce_to
        repeat_step = RepeatStep.new(
          workflow,
          steps: [{ "log" => "processing" }],
          until_condition: "{{false}}",
          max_iterations: 1,
        )

        # Apply config with direct syntax
        config = {
          "coerce_to" => "llm_boolean",
          "print_response" => true,
          "model" => "claude-3-haiku",
        }

        context_path = "test"
        state_manager = StateManager.new(workflow)
        executor = IterationExecutor.new(workflow, context_path, state_manager)

        # Apply the configuration
        executor.send(:apply_step_configuration, repeat_step, config)

        # Direct syntax should work
        assert_equal :llm_boolean, repeat_step.coerce_to
        assert_equal true, repeat_step.print_response
        assert_equal "claude-3-haiku", repeat_step.model
      end
    end
  end
end
