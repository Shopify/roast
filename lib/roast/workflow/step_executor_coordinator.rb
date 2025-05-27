# frozen_string_literal: true

require "roast/workflow/conditional_executor"
require "roast/workflow/step_executor_factory"
require "roast/workflow/step_type_resolver"

module Roast
  module Workflow
    # Coordinates the execution of different types of steps
    #
    # This class is responsible for routing steps to their appropriate executors
    # based on the step type. It acts as a central dispatcher that determines
    # which execution strategy to use for each step.
    #
    # Current Architecture:
    # - WorkflowExecutor.execute_steps still handles basic routing for backward compatibility
    # - This coordinator is used by WorkflowExecutor.execute_step for named steps
    # - Some step types (parallel) use the StepExecutorFactory pattern
    # - Other step types use direct execution methods
    #
    # TODO: Future refactoring should move all execution logic from WorkflowExecutor
    # to this coordinator and use the factory pattern consistently for all step types.
    class StepExecutorCoordinator
      def initialize(context:, dependencies:)
        @context = context
        @dependencies = dependencies
      end

      # Execute a step based on its type
      # @param step [String, Hash, Array] The step to execute
      # @param options [Hash] Execution options
      # @return [Object] The result of the step execution
      def execute(step, options = {})
        step_type = StepTypeResolver.resolve(step, @context)

        case step_type
        when StepTypeResolver::COMMAND_STEP
          # Command steps should also go through interpolation
          execute_string_step(step, options)
        when StepTypeResolver::GLOB_STEP
          execute_glob_step(step)
        when StepTypeResolver::ITERATION_STEP
          execute_iteration_step(step)
        when StepTypeResolver::CONDITIONAL_STEP
          execute_conditional_step(step)
        when StepTypeResolver::HASH_STEP
          execute_hash_step(step)
        when StepTypeResolver::PARALLEL_STEP
          # Use factory for parallel steps
          executor = StepExecutorFactory.for(step, workflow_executor)
          executor.execute(step)
        when StepTypeResolver::STRING_STEP
          execute_string_step(step, options)
        else
          execute_standard_step(step, options)
        end
      end

      private

      attr_reader :context, :dependencies

      def workflow_executor
        dependencies[:workflow_executor]
      end

      def interpolator
        dependencies[:interpolator]
      end

      def command_executor
        dependencies[:command_executor]
      end

      def iteration_executor
        dependencies[:iteration_executor]
      end

      def conditional_executor
        dependencies[:conditional_executor]
      end

      def step_orchestrator
        dependencies[:step_orchestrator]
      end

      def error_handler
        dependencies[:error_handler]
      end

      def execute_command_step(step, options)
        exit_on_error = options.fetch(:exit_on_error, true)
        resource_type = @context.resource_type

        error_handler.with_error_handling(step, resource_type: resource_type) do
          $stderr.puts "Executing: #{step} (Resource type: #{resource_type || "unknown"})"

          output = command_executor.execute(step, exit_on_error: exit_on_error)

          # Add to transcript
          workflow = context.workflow
          workflow.transcript << {
            user: "I just executed the following command: ```\n#{step}\n```\n\nHere is the output:\n\n```\n#{output}\n```",
          }
          workflow.transcript << { assistant: "Noted, thank you." }

          output
        end
      end

      def execute_glob_step(step)
        Dir.glob(step).join("\n")
      end

      def execute_iteration_step(step)
        name = step.keys.first
        command = step[name]

        case name
        when "repeat"
          iteration_executor.execute_repeat(command)
        when "each"
          validate_each_step!(step)
          iteration_executor.execute_each(step)
        end
      end

      def execute_conditional_step(step)
        conditional_executor.execute_conditional(step)
      end

      def execute_hash_step(step)
        name, command = step.to_a.flatten
        interpolated_name = interpolator.interpolate(name)

        if command.is_a?(Hash)
          workflow_executor.execute_steps([command])
        else
          interpolated_command = interpolator.interpolate(command)
          exit_on_error = context.exit_on_error?(interpolated_name)

          # Execute the command directly using the appropriate executor
          result = execute(interpolated_command, { exit_on_error: exit_on_error })
          context.workflow.output[interpolated_name] = result
          result
        end
      end

      def execute_string_step(step, options = {})
        # Check for glob before interpolation
        if StepTypeResolver.glob_step?(step, context)
          return execute_glob_step(step)
        end

        interpolated_step = interpolator.interpolate(step)

        if StepTypeResolver.command_step?(interpolated_step)
          # Command step - execute directly, preserving any passed options
          exit_on_error = options.fetch(:exit_on_error, true)
          execute_command_step(interpolated_step, { exit_on_error: exit_on_error })
        else
          exit_on_error = options.fetch(:exit_on_error, context.exit_on_error?(step))
          execute_standard_step(interpolated_step, { exit_on_error: exit_on_error })
        end
      end

      def execute_standard_step(step, options)
        exit_on_error = options.fetch(:exit_on_error, true)
        step_orchestrator.execute_step(step, exit_on_error: exit_on_error)
      end

      def validate_each_step!(step)
        unless step.key?("as") && step.key?("steps")
          raise WorkflowExecutor::ConfigurationError,
            "Invalid 'each' step format. 'as' and 'steps' must be at the same level as 'each'"
        end
      end
    end
  end
end
