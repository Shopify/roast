# frozen_string_literal: true

require "roast/workflow/step_executor_factory"

module Roast
  module Workflow
    # Handles the orchestration of step execution, managing the flow and control
    # of individual steps without knowing how to execute them
    #
    # This class is specifically for executing CUSTOM steps defined in the workflow's
    # step directory (e.g., steps/*.rb files). It loads and executes Ruby step files
    # that define a `call` method.
    #
    # Note: The execute_steps method in this class appears to be dead code - it's only
    # used in tests and creates a circular dependency with StepExecutorFactory.
    # The primary method execute_step is used by StepExecutorCoordinator for
    # executing custom Ruby steps.
    #
    # TODO: Consider renaming this class to CustomStepOrchestrator to clarify its purpose
    # and remove the unused execute_steps method.
    class StepOrchestrator
      def initialize(workflow, step_loader, state_manager, error_handler, workflow_executor)
        @workflow = workflow
        @step_loader = step_loader
        @state_manager = state_manager
        @error_handler = error_handler
        @workflow_executor = workflow_executor
      end

      def execute_step(name, exit_on_error: true)
        resource_type = @workflow.respond_to?(:resource) ? @workflow.resource&.type : nil

        @error_handler.with_error_handling(name, resource_type: resource_type) do
          $stderr.puts "Executing: #{name} (Resource type: #{resource_type || "unknown"})"

          step_object = @step_loader.load(name)
          step_result = step_object.call

          # Store result in workflow output
          # Note: For typical workflows where each step writes to a unique key,
          # this is safe even in parallel execution. If concurrent writes to the
          # same key become necessary, additional synchronization may be required.
          @workflow.output[name] = step_result

          # Save state after each step
          @state_manager.save_state(name, step_result)

          step_result
        end
      end

      # DEAD CODE: This method is only used in tests and creates a circular dependency
      # with StepExecutorFactory. It should be removed in future refactoring.
      # The functionality it provides is redundant with WorkflowExecutor.execute_steps
      def execute_steps(workflow_steps)
        workflow_steps.each do |workflow_step|
          executor = StepExecutorFactory.for(workflow_step, @workflow_executor)
          executor.execute(workflow_step)

          # Handle pause after string steps
          if workflow_step.is_a?(String) && @workflow.pause_step_name == workflow_step
            Kernel.binding.irb # rubocop:disable Lint/Debugger
          end
        end
      end
    end
  end
end
