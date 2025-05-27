# frozen_string_literal: true

module Roast
  module Workflow
    # Determines the type of a step and how it should be executed
    class StepTypeResolver
      # Step type constants
      COMMAND_STEP = :command
      GLOB_STEP = :glob
      ITERATION_STEP = :iteration
      CONDITIONAL_STEP = :conditional
      HASH_STEP = :hash
      PARALLEL_STEP = :parallel
      STRING_STEP = :string
      STANDARD_STEP = :standard

      # Special step names for iterations
      ITERATION_STEPS = ["repeat", "each"].freeze

      # Special step names for conditionals
      CONDITIONAL_STEPS = ["if", "unless"].freeze

      class << self
        # Resolve the type of a step
        # @param step [String, Hash, Array] The step to analyze
        # @param context [WorkflowContext] The workflow context
        # @return [Symbol] The step type
        def resolve(step, context = nil)
          case step
          when String
            resolve_string_step(step, context)
          when Hash
            resolve_hash_step(step)
          when Array
            PARALLEL_STEP
          else
            STANDARD_STEP
          end
        end

        # Check if a step is a command step
        # @param step [String] The step to check
        # @return [Boolean] true if it's a command step
        def command_step?(step)
          step.is_a?(String) && step.start_with?("$(")
        end

        # Check if a step is a glob pattern
        # @param step [String] The step to check
        # @param context [WorkflowContext, nil] The workflow context
        # @return [Boolean] true if it's a glob pattern
        def glob_step?(step, context = nil)
          return false unless step.is_a?(String) && step.include?("*")

          # Only treat as glob if we don't have a resource
          context.nil? || !context.has_resource?
        end

        # Check if a step is an iteration step
        # @param step [Hash] The step to check
        # @return [Boolean] true if it's an iteration step
        def iteration_step?(step)
          return false unless step.is_a?(Hash)

          step_name = step.keys.first
          ITERATION_STEPS.include?(step_name)
        end

        # Check if a step is a conditional step
        # @param step [Hash] The step to check
        # @return [Boolean] true if it's a conditional step
        def conditional_step?(step)
          return false unless step.is_a?(Hash)

          step_name = step.keys.first
          CONDITIONAL_STEPS.include?(step_name)
        end

        # Extract the step name from various step formats
        # @param step [String, Hash, Array] The step
        # @return [String, nil] The step name or nil
        def extract_name(step)
          case step
          when String
            step
          when Hash
            step.keys.first
          when Array
            nil # Parallel steps don't have a single name
          end
        end

        private

        def resolve_string_step(step, context)
          if command_step?(step)
            COMMAND_STEP
          elsif glob_step?(step, context)
            GLOB_STEP
          else
            STRING_STEP
          end
        end

        def resolve_hash_step(step)
          if iteration_step?(step)
            ITERATION_STEP
          elsif conditional_step?(step)
            CONDITIONAL_STEP
          else
            HASH_STEP
          end
        end
      end
    end
  end
end
