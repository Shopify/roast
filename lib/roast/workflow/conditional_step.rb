# frozen_string_literal: true

require "roast/workflow/base_step"
require "roast/workflow/command_executor"
require "roast/workflow/expression_utils"
require "roast/workflow/interpolator"

module Roast
  module Workflow
    class ConditionalStep < BaseStep
      include ExpressionUtils
      def initialize(workflow, config:, name:, context_path:, **kwargs)
        super(workflow, name: name, context_path: context_path, **kwargs)

        @config = config
        @condition = config["if"] || config["unless"]
        @is_unless = config.key?("unless")
        @then_steps = config["then"] || []
        @else_steps = config["else"] || []
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
          # Execute the steps using the workflow's execute_steps method
          @workflow.execute_steps(steps_to_execute)
        end

        # Return a result indicating which branch was taken
        { condition_result: condition_result, branch_executed: condition_result ? "then" : "else" }
      end

      private

      def evaluate_condition(condition)
        return false unless condition.is_a?(String)

        if ruby_expression?(condition)
          evaluate_ruby_expression(condition)
        elsif bash_command?(condition)
          evaluate_bash_command(condition)
        else
          # Treat as a step name or direct boolean
          evaluate_step_or_value(condition)
        end
      end

      def evaluate_ruby_expression(expression)
        expr = extract_expression(expression)
        begin
          !!@workflow.instance_eval(expr)
        rescue => e
          $stderr.puts "Warning: Error evaluating expression '#{expr}': #{e.message}"
          false
        end
      end

      def evaluate_bash_command(command)
        cmd = extract_command(command)
        executor = CommandExecutor.new(logger: Roast::Helpers::Logger)
        begin
          result = executor.execute(cmd, exit_on_error: false)
          # For conditionals, we care about the exit status
          result[:success]
        rescue => e
          $stderr.puts "Warning: Error executing command '#{cmd}': #{e.message}"
          false
        end
      end

      def evaluate_step_or_value(input)
        # Check if it's a reference to a previous step output
        if @workflow.output.key?(input)
          result = @workflow.output[input]
          # Coerce to boolean
          return false if result.nil? || result == false || result == "" || result == "false"

          return true
        end

        # Otherwise treat as a direct value
        input.to_s.downcase == "true"
      end
    end
  end
end
