# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Registry pattern for step executors - eliminates case statements
    # and follows Open/Closed Principle
    class StepExecutorRegistry
      class UnknownStepTypeError < Roast::Error; end

      @executors = {}
      @type_matchers = []

      class << self
        # Register an executor for a specific class
        # @param klass [Class] The class to match
        # @param executor_class [Class] The executor class to use
        def register(klass, executor_class)
          @executors[klass] = executor_class
        end

        # Register an executor with a custom matcher
        # @param matcher [Proc] A proc that returns true if the step matches
        # @param executor_class [Class] The executor class to use
        def register_with_matcher(matcher, executor_class)
          @type_matchers << { matcher: matcher, executor_class: executor_class }
        end

        # Find the appropriate executor for a step
        # @param step [Object] The step to find an executor for
        # @param workflow_executor [WorkflowExecutor] The workflow executor instance
        # @return [Object] An instance of the appropriate executor
        def for(step, workflow_executor)
          executor_class = find_executor_class(step)

          unless executor_class
            raise UnknownStepTypeError, "No executor registered for step type: #{step.class} (#{step.inspect})"
          end

          executor_class.new(workflow_executor)
        end

        # Clear all registrations (useful for testing)
        def clear!
          @executors.clear
          @type_matchers.clear
          StepExecutorFactory.instance_variable_set(:@defaults_registered, false)
        end

        # Get all registered executors (useful for debugging)
        def registered_executors
          @executors.dup
        end

        private

        def find_executor_class(step)
          return @executors[step.class] if @executors[step.class]

          # Then check custom matchers
          matcher_entry = @type_matchers.find { |entry| entry[:matcher].call(step) }
          return matcher_entry[:executor_class] if matcher_entry

          # Finally check inheritance chain
          step.class.ancestors.each do |ancestor|
            executor_class = @executors[ancestor]
            return executor_class if executor_class
          end

          nil
        end
      end
    end
  end
end
