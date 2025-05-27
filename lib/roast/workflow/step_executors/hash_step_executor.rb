# frozen_string_literal: true

require "roast/workflow/step_executors/base_step_executor"

module Roast
  module Workflow
    module StepExecutors
      class HashStepExecutor < BaseStepExecutor
        def execute(step)
          # execute a command and store the output in a variable
          name, command = step.to_a.flatten

          # Interpolate variable name if it contains {{}}
          interpolated_name = workflow_executor.interpolate(name)

          if command.is_a?(Hash)
            workflow_executor.execute_steps([command])
          else
            # Interpolate command value
            interpolated_command = workflow_executor.interpolate(command)

            # Check if this step has exit_on_error configuration
            step_config = config_hash[interpolated_name]
            exit_on_error = step_config.is_a?(Hash) ? step_config.fetch("exit_on_error", true) : true

            workflow.output[interpolated_name] = workflow_executor.execute_step(interpolated_command, exit_on_error: exit_on_error)
          end
        end
      end
    end
  end
end
