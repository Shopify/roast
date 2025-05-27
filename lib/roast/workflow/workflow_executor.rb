# frozen_string_literal: true

require "English"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "roast/workflow/command_executor"
require "roast/workflow/conditional_executor"
require "roast/workflow/error_handler"
require "roast/workflow/interpolator"
require "roast/workflow/iteration_executor"
require "roast/workflow/parallel_executor"
require "roast/workflow/state_manager"
require "roast/workflow/step_executor_factory"
require "roast/workflow/step_executor_coordinator"
require "roast/workflow/step_loader"
require "roast/workflow/step_orchestrator"
require "roast/workflow/step_type_resolver"
require "roast/workflow/workflow_context"

module Roast
  module Workflow
    # Handles the execution of workflow steps, including orchestration and threading
    #
    # Current Architecture:
    # This class has two parallel execution systems that need to be unified:
    #
    # 1. Direct execution path (execute_steps method):
    #    - Used by WorkflowRunner and iteration steps
    #    - Handles basic routing based on step type (Hash, Array, String)
    #    - Directly executes steps without going through StepExecutorCoordinator
    #
    # 2. Coordinator-based execution path (execute_step method):
    #    - Used for named steps
    #    - Delegates to StepExecutorCoordinator for type resolution and execution
    #    - More flexible and extensible design
    #
    # TODO: Future refactoring should:
    # - Unify these two execution paths
    # - Move all routing logic to StepExecutorCoordinator
    # - Use StepExecutorFactory consistently for all step types
    # - Remove the execute_hash_step, execute_parallel_steps, execute_string_step methods
    class WorkflowExecutor
      # Define custom exception classes for specific error scenarios
      class WorkflowExecutorError < StandardError
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

      attr_reader :context, :step_loader, :state_manager

      delegate :workflow, :config_hash, :context_path, to: :context

      def initialize(workflow, config_hash, context_path,
        error_handler: nil, step_loader: nil, command_executor: nil,
        interpolator: nil, state_manager: nil, iteration_executor: nil,
        conditional_executor: nil, step_orchestrator: nil, step_executor_coordinator: nil)
        # Create context object to reduce data clump
        @context = WorkflowContext.new(
          workflow: workflow,
          config_hash: config_hash,
          context_path: context_path,
        )

        # Dependencies with defaults
        @error_handler = error_handler || ErrorHandler.new
        @step_loader = step_loader || StepLoader.new(workflow, config_hash, context_path)
        @command_executor = command_executor || CommandExecutor.new(logger: @error_handler)
        @interpolator = interpolator || Interpolator.new(workflow, logger: @error_handler)
        @state_manager = state_manager || StateManager.new(workflow, logger: @error_handler)
        @iteration_executor = iteration_executor || IterationExecutor.new(workflow, context_path, @state_manager)
        @conditional_executor = conditional_executor || ConditionalExecutor.new(workflow, context_path, @state_manager)
        @step_orchestrator = step_orchestrator || StepOrchestrator.new(workflow, @step_loader, @state_manager, @error_handler, self)

        # Initialize coordinator with dependencies
        @step_executor_coordinator = step_executor_coordinator || StepExecutorCoordinator.new(
          context: @context,
          dependencies: {
            workflow_executor: self,
            interpolator: @interpolator,
            command_executor: @command_executor,
            iteration_executor: @iteration_executor,
            conditional_executor: @conditional_executor,
            step_orchestrator: @step_orchestrator,
            error_handler: @error_handler,
          },
        )
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
        workflow_steps.each do |step|
          case step
          when Hash
            execute_hash_step(step)
          when Array
            execute_parallel_steps(step)
          when String
            execute_string_step(step)
            # Handle pause after string steps
            if workflow.pause_step_name == step
              Kernel.binding.irb # rubocop:disable Lint/Debugger
            end
          else
            @step_orchestrator.execute_step(step)
          end
        end
      end

      def interpolate(text)
        @interpolator.interpolate(text)
      end

      def execute_step(name, exit_on_error: true)
        @step_executor_coordinator.execute(name, exit_on_error: exit_on_error)
      rescue StepLoader::StepNotFoundError => e
        raise StepNotFoundError.new(e.message, step_name: e.step_name, original_error: e.original_error)
      rescue StepLoader::StepExecutionError => e
        raise StepExecutionError.new(e.message, step_name: e.step_name, original_error: e.original_error)
      end

      # Methods moved to StepExecutorCoordinator but kept for backward compatibility
      # These are only used by execute_steps and should be removed when we unify
      # the execution paths to use StepExecutorCoordinator exclusively.
      private

      def execute_hash_step(step)
        @step_executor_coordinator.execute(step)
      end

      def execute_parallel_steps(steps)
        @step_executor_coordinator.execute(steps)
      end

      def execute_string_step(step)
        @step_executor_coordinator.execute(step)
      end
    end
  end
end
