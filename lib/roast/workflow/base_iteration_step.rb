# frozen_string_literal: true

require "roast/workflow/expression_utils"
require "roast/workflow/llm_boolean_coercer"
require "roast/workflow/workflow_executor"

module Roast
  module Workflow
    # Base class for iteration steps (RepeatStep and EachStep)
    class BaseIterationStep < BaseStep
      include ExpressionUtils
      DEFAULT_MAX_ITERATIONS = 100

      attr_reader :steps

      def initialize(workflow, steps:, **kwargs)
        super(workflow, **kwargs)
        @steps = steps
        # Don't initialize cmd_tool here - we'll do it lazily when needed
      end

      protected

      # Process various types of inputs and convert to appropriate types for iteration
      def process_iteration_input(input, context, coerce_to: nil)
        if input.is_a?(String)
          if ruby_expression?(input)
            process_ruby_expression(input, context, coerce_to)
          elsif bash_command?(input)
            process_bash_command(input, coerce_to)
          else
            process_step_or_prompt(input, context, coerce_to)
          end
        else
          # Non-string inputs are coerced as-is
          coerce_result(input, coerce_to)
        end
      end

      # Interpolates {{expression}} in a string with values from the workflow context
      def interpolate_expression(text, context)
        return text unless text.is_a?(String) && text.include?("{{") && text.include?("}}")

        # Replace all {{expression}} with their evaluated values
        text.gsub(/\{\{([^}]+)\}\}/) do |match|
          expression = extract_expression(match)
          begin
            # Evaluate the expression in the workflow's context
            result = context.instance_eval(expression)
            result.inspect # Convert to string representation
          rescue => e
            warn_interpolation_error(expression, e)
            match # Return the original match to preserve it in the string
          end
        end
      end

      # Execute nested steps
      def execute_nested_steps(steps, context, executor = nil)
        executor ||= WorkflowExecutor.new(context, {}, context_path)
        results = []

        steps.each do |step|
          result = case step
          when String
            executor.execute_step(step)
          when Hash, Array
            executor.execute_steps([step])
          end
          results << result
        end

        results
      end

      private

      # Process a Ruby expression
      def process_ruby_expression(input, context, coerce_to)
        expression = extract_expression(input)
        result = evaluate_ruby_expression(expression, context)
        coerce_result(result, coerce_to)
      end

      # Process a Bash command
      def process_bash_command(input, coerce_to)
        command = extract_command(input)
        execute_command(command, coerce_to)
      end

      # Process a step name or prompt
      def process_step_or_prompt(input, context, coerce_to)
        step_result = execute_step_by_name(input, context)
        coerce_result(step_result, coerce_to)
      end

      # Execute a Ruby expression in the workflow context
      def evaluate_ruby_expression(expression, context)
        context.instance_eval(expression)
      rescue => e
        warn_expression_error(expression, e)
        nil
      end

      # Execute a bash command and return its result
      def execute_command(command, coerce_to)
        # Use the Cmd module to execute the command
        result = Roast::Tools::Cmd.call(command)

        if coerce_to == :boolean
          # For boolean coercion, use exit status (assume success unless error message)
          !result.to_s.start_with?("Error")
        else
          # For other uses, return the output
          result
        end
      end

      # Execute a step by name and return its result
      def execute_step_by_name(step_name, context)
        # Reuse existing step execution logic
        executor = WorkflowExecutor.new(context, {}, context_path)
        executor.execute_step(step_name)
      end

      # Coerce results to the appropriate type
      def coerce_result(result, coerce_to)
        return coerce_to_boolean(result) if coerce_to == :boolean
        return coerce_to_iterable(result) if coerce_to == :iterable
        return coerce_to_llm_boolean(result) if coerce_to == :llm_boolean

        # Default - return as is
        result
      end

      # Force a value to boolean
      def coerce_to_boolean(result)
        !!result
      end

      # Ensure a value is iterable
      def coerce_to_iterable(result)
        return result if result.respond_to?(:each)

        result.to_s.split("\n")
      end

      # Convert LLM response to boolean
      def coerce_to_llm_boolean(result)
        LlmBooleanCoercer.coerce(result)
      end

      # Log a warning for expression evaluation errors
      def warn_expression_error(expression, error)
        $stderr.puts "Warning: Error evaluating expression '#{expression}': #{error.message}"
      end

      # Log a warning for interpolation errors
      def warn_interpolation_error(expression, error)
        $stderr.puts "Warning: Error interpolating {{#{expression}}}: #{error.message}"
      end
    end
  end
end
