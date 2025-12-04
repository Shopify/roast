# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Shared module for evaluating expressions in workflow steps
    module ExpressionEvaluator
      include ExpressionUtils

      # Evaluate a Ruby expression in the workflow context
      # @param expression [String] The expression to evaluate
      # @return [Object] The result of the expression
      def evaluate_ruby_expression(expression)
        expr = extract_expression(expression)
        begin
          @workflow.instance_eval(expr)
        rescue => e
          Roast::Log.warn("Warning: Error evaluating expression '#{expr}': #{e.message}")
          nil
        end
      end

      # Evaluate a bash command and return its output
      # @param command [String] The command to execute
      # @param for_condition [Boolean] If true, returns success status; if false, returns output
      # @return [Boolean, String, nil] Command result based on for_condition flag
      def evaluate_bash_command(command, for_condition: false)
        cmd = command.start_with?("$(") ? command : extract_command(command)
        executor = CommandExecutor.new(logger: Roast::Helpers::Logger)

        begin
          output = executor.execute(cmd, exit_on_error: false)

          # Print command output in verbose mode
          if @workflow.verbose
            Roast::Log.debug("Evaluating command: #{cmd}")
            Roast::Log.debug("Command output:")
            Roast::Log.debug(output)
            Roast::Log.debug("")
          end

          if for_condition
            # For conditions, we care about the exit status (success = true)
            # Check if output contains exit status marker
            !output.include?("[Exit status:")
          else
            # For case expressions, we want the actual output
            output.strip
          end
        rescue => e
          Roast::Log.warn("Warning: Error executing command '#{cmd}': #{e.message}")
          for_condition ? false : nil
        end
      end

      # Evaluate a step reference or direct value
      # @param input [String] The input to evaluate
      # @return [Boolean, Object] The result for conditions, or the value itself
      def evaluate_step_or_value(input, for_condition: false)
        # Check if it's a reference to a previous step output
        if @workflow.output.key?(input)
          result = @workflow.output[input]

          if for_condition
            # Coerce to boolean for conditions
            return false if result.nil? || result == false || result == "" || result == "false"

            return true
          else
            # Return the actual value for case expressions
            return result
          end
        end

        # Otherwise treat as a direct value
        if for_condition
          input.to_s.downcase == "true"
        else
          input
        end
      end
    end
  end
end
