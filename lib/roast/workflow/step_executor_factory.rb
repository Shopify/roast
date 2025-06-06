# frozen_string_literal: true

module Roast
  module Workflow
    # Factory for creating step executors - now delegates to registry
    class StepExecutorFactory
      class << self
        # Method to ensure default executors are registered
        def ensure_defaults_registered
          return if @defaults_registered

          StepExecutorRegistry.register(Hash, StepExecutors::HashStepExecutor)
          StepExecutorRegistry.register(Array, StepExecutors::ParallelStepExecutor)
          StepExecutorRegistry.register(String, StepExecutors::StringStepExecutor)

          @defaults_registered = true
        end
      end

      # Initialize on first use
      ensure_defaults_registered

      class << self
        # Delegate to the registry for backward compatibility
        def for(step, workflow_executor)
          ensure_defaults_registered
          StepExecutorRegistry.for(step, workflow_executor)
        end

        # Allow registration of new executors
        def register(klass, executor_class)
          StepExecutorRegistry.register(klass, executor_class)
        end

        # Allow registration with custom matchers
        def register_with_matcher(matcher, executor_class)
          StepExecutorRegistry.register_with_matcher(matcher, executor_class)
        end
      end
    end
  end
end
