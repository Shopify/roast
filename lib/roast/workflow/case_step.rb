# frozen_string_literal: true

module Roast
  module Workflow
    class CaseStep < BaseStep
      include ExpressionEvaluator

      def initialize(workflow, config:, name:, context_path:, workflow_executor:, **kwargs)
        super(workflow, name: name, context_path: context_path, **kwargs)

        @config = config
        @case_expression = config["case"]
        @when_clauses = config["when"] || {}
        @else_steps = config["else"] || []
        @workflow_executor = workflow_executor
      end

      def call
        # Evaluate the case expression to get the value to match against
        case_value = evaluate_case_expression(@case_expression)

        # Find the matching when clause
        matched_key = find_matching_when_clause(case_value)

        # Determine which steps to execute
        steps_to_execute = if matched_key
          @when_clauses[matched_key]
        else
          @else_steps
        end

        # Execute the selected steps
        unless steps_to_execute.nil? || steps_to_execute.empty?
          @workflow_executor.execute_steps(steps_to_execute)
        end

        # Return a result indicating which branch was taken
        {
          case_value: case_value,
          matched_when: matched_key,
          branch_executed: matched_key || (steps_to_execute.empty? ? "none" : "else"),
        }
      end

      private

      def evaluate_case_expression(expression)
        return unless expression

        # Handle interpolated expressions
        if expression.is_a?(String)
          interpolated = Interpolator.new(@workflow).interpolate(expression)

          if ruby_expression?(interpolated)
            evaluate_ruby_expression(interpolated)
          elsif bash_command?(interpolated)
            evaluate_bash_command(interpolated, for_condition: false)
          else
            # Return the interpolated value as-is
            interpolated
          end
        else
          expression
        end
      end

      def find_matching_when_clause(case_value)
        # Convert case_value to string for comparison
        case_value_str = case_value.to_s

        @when_clauses.keys.find do |when_key|
          # Direct string comparison
          when_key.to_s == case_value_str
        end
      end
    end
  end
end
