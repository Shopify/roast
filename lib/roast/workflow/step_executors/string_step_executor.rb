# frozen_string_literal: true

module Roast
  module Workflow
    module StepExecutors
      class StringStepExecutor < BaseStepExecutor
        def execute(step)
          # Interpolate any {{}} expressions before executing the step
          interpolated_step = workflow_executor.interpolate(step)

          # For command steps, check if there's an exit_on_error configuration
          # We need to extract the step name to look up configuration
          if interpolated_step.starts_with?("$(")
            # This is a direct command without a name, so exit_on_error defaults to true
            workflow_executor.execute_step(interpolated_step)
          else
            # Check if this step has exit_on_error configuration
            step_config = config_hash[step]
            exit_on_error = step_config.is_a?(Hash) ? step_config.fetch("exit_on_error", true) : true

            workflow_executor.execute_step(interpolated_step, exit_on_error: exit_on_error)
          end
        end
      end
    end
  end
end
