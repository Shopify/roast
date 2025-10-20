# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Decorator that adds token consumption reporting to step execution
    class StepExecutorWithReporting
      def initialize(base_executor, context, output: $stderr)
        @base_executor = base_executor
        @context = context
        @reporter = StepCompletionReporter.new(output: output)
        @name_extractor = StepNameExtractor.new
      end

      def execute(step, **options)
        # Track tokens before execution
        tokens_before = @context.workflow.context_manager&.total_tokens || 0

        # Execute the step
        result = @base_executor.execute(step, **options)

        # Report token consumption after successful execution
        tokens_after = @context.workflow.context_manager&.total_tokens || 0
        tokens_consumed = tokens_after - tokens_before

        step_type = StepTypeResolver.resolve(step, @context)
        step_name = @name_extractor.extract(step, step_type)
        @reporter.report(step_name, tokens_consumed, tokens_after, context_manager: @context.workflow.context_manager)

        result
      end

      # Override execute_steps to ensure reporting happens for each step
      def execute_steps(workflow_steps)
        workflow_steps.each_with_index do |step, index|
          is_last_step = (index == workflow_steps.length - 1)
          case step
          when Hash
            execute(step, is_last_step:)
          when Array
            execute(step, is_last_step:)
          when String
            execute(step, is_last_step:)
            # Handle pause after string steps
            if @context.workflow.pause_step_name == step
              Kernel.binding.irb # rubocop:disable Lint/Debugger
            end
          else
            # For other types, delegate to base executor
            execute(step, is_last_step:)
          end
        end
      end

      # Delegate all other methods to the base executor
      def method_missing(method, *args, **kwargs, &block)
        if @base_executor.respond_to?(method)
          @base_executor.send(method, *args, **kwargs, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        @base_executor.respond_to?(method, include_private) || super
      end
    end
  end
end
