# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles the execution of workflow steps, including orchestration and threading
    #
    # This class now delegates all step execution to StepExecutorCoordinator,
    # which handles type resolution and execution for all step types.
    # The circular dependency between executors and workflow has been broken
    # by introducing the StepRunner interface.
    class WorkflowExecutor
      # Define custom exception classes for specific error scenarios
      class WorkflowExecutorError < Roast::Error
        attr_reader :step_name, :original_error

        def initialize(message, step_name: nil, original_error: nil)
          @step_name = step_name
          @original_error = original_error
          super(message)
        end
      end

      class StepExecutionError < WorkflowExecutorError; end
      class StepNotFoundError < WorkflowExecutorError; end
      class InterpolationError < WorkflowExecutorError; end
      class StateError < WorkflowExecutorError; end
      class ConfigurationError < WorkflowExecutorError; end

      attr_reader :context, :step_loader, :state_manager, :step_executor_coordinator

      delegate :workflow, :config_hash, :context_path, to: :context

      # Initialize a new WorkflowExecutor
      #
      # @param workflow [BaseWorkflow] The workflow instance to execute
      # @param config_hash [Hash] The workflow configuration
      # @param context_path [String] The base path for the workflow
      # @param error_handler [ErrorHandler] Optional custom error handler
      # @param step_loader [StepLoader] Optional custom step loader
      # @param command_executor [CommandExecutor] Optional custom command executor
      # @param interpolator [Interpolator] Optional custom interpolator
      # @param state_manager [StateManager] Optional custom state manager
      # @param iteration_executor [IterationExecutor] Optional custom iteration executor
      # @param conditional_executor [ConditionalExecutor] Optional custom conditional executor
      # @param step_executor_coordinator [StepExecutorCoordinator] Optional custom step executor coordinator
      # @param phase [Symbol] The execution phase - determines where to load steps from
      #   Valid values:
      #   - :steps (default) - Load steps from the main steps directory
      #   - :pre_processing - Load steps from the pre_processing directory
      #   - :post_processing - Load steps from the post_processing directory
      def initialize(workflow, config_hash, context_path,
        error_handler: nil, step_loader: nil, command_executor: nil,
        interpolator: nil, state_manager: nil, iteration_executor: nil,
        conditional_executor: nil, step_executor_coordinator: nil,
        phase: :steps)
        # Create context object to reduce data clump
        @context = WorkflowContext.new(
          workflow: workflow,
          config_hash: config_hash,
          context_path: context_path,
        )

        # Dependencies with defaults
        @error_handler = error_handler || ErrorHandler.new(workflow)
        @step_loader = step_loader || StepLoader.new(workflow, config_hash, context_path, phase: phase)
        @command_executor = command_executor || CommandExecutor.new(logger: @error_handler)
        @interpolator = interpolator || Interpolator.new(workflow, logger: @error_handler)
        @state_manager = state_manager || StateManager.new(workflow, logger: @error_handler, storage_type: workflow.storage_type)
        @iteration_executor = iteration_executor || IterationExecutor.new(workflow, context_path, @state_manager, config_hash)
        @conditional_executor = conditional_executor || ConditionalExecutor.new(workflow, context_path, @state_manager, self)

        # Initialize coordinator with dependencies
        base_coordinator = step_executor_coordinator || StepExecutorCoordinator.new(
          context: @context,
          dependencies: {
            workflow_executor: self,
            interpolator: @interpolator,
            command_executor: @command_executor,
            iteration_executor: @iteration_executor,
            conditional_executor: @conditional_executor,
            step_loader: @step_loader,
            state_manager: @state_manager,
            error_handler: @error_handler,
          },
        )

        # Only wrap with reporting decorator if workflow has token tracking enabled
        @step_executor_coordinator = if workflow.respond_to?(:context_manager) && workflow.context_manager
          StepExecutorWithReporting.new(base_coordinator, @context)
        else
          base_coordinator
        end
      end

      # Logger interface methods for backward compatibility
      def log_error(message)
        @error_handler.log_error(message)
      end

      def log_warning(message)
        @error_handler.log_warning(message)
      end

      def warn(message)
        @error_handler.log_warning(message)
      end

      def error(message)
        @error_handler.log_error(message)
      end

      def execute_steps(workflow_steps)
        @step_executor_coordinator.execute_steps(workflow_steps)
      end

      def interpolate(text)
        @interpolator.interpolate(text)
      end

      def execute_step(name, exit_on_error: true, is_last_step: nil)
        @step_executor_coordinator.execute(name, exit_on_error:, is_last_step:)
      rescue StepLoader::StepNotFoundError => e
        raise StepNotFoundError.new(e.message, step_name: e.step_name, original_error: e.original_error)
      rescue StepLoader::StepExecutionError => e
        raise StepExecutionError.new(e.message, step_name: e.step_name, original_error: e.original_error)
      end
    end
  end
end
