# frozen_string_literal: true

module Roast
  module Workflow
    # Handles the orchestration of step execution, managing the flow and control
    # of individual steps without knowing how to execute them
    #
    # This class is specifically for executing CUSTOM steps defined in the workflow's
    # step directory (e.g., steps/*.rb files). It loads and executes Ruby step files
    # that define a `call` method.
    #
    # The primary method execute_step is used by StepExecutorCoordinator for
    # executing custom Ruby steps.
    #
    # TODO: Consider renaming this class to CustomStepOrchestrator to clarify its purpose
    class StepOrchestrator
      def initialize(workflow, step_loader, state_manager, error_handler, workflow_executor)
        @workflow = workflow
        @step_loader = step_loader
        @state_manager = state_manager
        @error_handler = error_handler
        @workflow_executor = workflow_executor
      end

      def execute_step(name, exit_on_error: true, step_key: nil, **options)
        resource_type = @workflow.respond_to?(:resource) ? @workflow.resource&.type : nil

        @error_handler.with_error_handling(name, resource_type: resource_type) do
          $stderr.puts "▶️ Executing: #{name} (Resource type: #{resource_type || "unknown"})"

          # Use step_key for loading if provided, otherwise use name
          load_key = step_key || name
          is_last_step = options[:is_last_step]
          step_object = @step_loader.load(name, step_key: load_key, is_last_step:, **options)
          step_result = step_object.call

          # Store result in workflow output
          @workflow.output[name] = step_result

          # Save state after each step
          @state_manager.save_state(name, step_result)

          step_result
        end
      end
    end
  end
end
