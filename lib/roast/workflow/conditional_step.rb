# frozen_string_literal: true

module Roast
  module Workflow
    class ConditionalStep < BaseStep
      include ExpressionEvaluator

      def initialize(workflow, config:, name:, context_path:, workflow_executor:, **kwargs)
        super(workflow, name: name, context_path: context_path, **kwargs)

        @config = config
        @condition = config["if"] || config["unless"]
        @is_unless = config.key?("unless")
        @then_steps = config["then"] || []
        @else_steps = config["else"] || []
        @workflow_executor = workflow_executor
      end

      def call
        # Evaluate the condition
        condition_result = evaluate_condition(@condition)

        # Invert the result if this is an 'unless' condition
        condition_result = !condition_result if @is_unless

        # Select which steps to execute based on the condition
        steps_to_execute = condition_result ? @then_steps : @else_steps

        # Execute the selected steps
        unless steps_to_execute.empty?
          @workflow_executor.execute_steps(steps_to_execute)
        end

        # Return a result indicating which branch was taken
        { condition_result: condition_result, branch_executed: condition_result ? "then" : "else" }
      end

      private

      def evaluate_condition(condition)
        return false unless condition.is_a?(String)

        if ruby_expression?(condition)
          # For conditionals, coerce result to boolean
          !!evaluate_ruby_expression(condition)
        elsif bash_command?(condition)
          evaluate_bash_command(condition, for_condition: true)
        else
          # Treat as a step name or direct boolean
          evaluate_step_or_value(condition, for_condition: true)
        end
      end
    end
  end
end
