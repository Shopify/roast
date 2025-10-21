# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Interface for running workflow steps.
    # This abstraction breaks the circular dependency between executors and the workflow.
    class StepRunner
      def initialize(coordinator)
        @coordinator = coordinator
      end

      # Execute a list of steps
      def execute_steps(steps)
        @coordinator.execute_steps(steps)
      end

      # Execute a single step
      def execute_step(step, **options)
        @coordinator.execute_step(step, **options)
      end
    end
  end
end
