# frozen_string_literal: true

module Roast
  module Workflow
    # Handles error logging and instrumentation for workflow execution
    class ErrorHandler
      def initialize(retry_coordinator: nil)
        # Use the Roast logger singleton
        @retry_coordinator = retry_coordinator || Roast::Retry::RetryCoordinator.new
      end

      def with_error_handling(step_name, resource_type: nil, step_config: nil, &block)
        start_time = Time.now

        ActiveSupport::Notifications.instrument("roast.step.start", {
          step_name: step_name,
          resource_type: resource_type,
        })

        result = if step_config && @retry_coordinator
          @retry_coordinator.execute_with_retry(step_config, &block)
        else
          yield
        end

        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.complete", {
          step_name: step_name,
          resource_type: resource_type,
          success: true,
          execution_time: execution_time,
          result_size: result.to_s.length,
        })

        result
      rescue WorkflowExecutor::WorkflowExecutorError => e
        handle_workflow_error(e, step_name, resource_type, start_time)
        raise
      rescue CommandExecutor::CommandExecutionError => e
        handle_workflow_error(e, step_name, resource_type, start_time)
        raise
      rescue => e
        handle_generic_error(e, step_name, resource_type, start_time)
      end

      def log_error(message)
        Roast::Helpers::Logger.error(message)
      end

      def log_warning(message)
        Roast::Helpers::Logger.warn(message)
      end

      # Alias methods for compatibility
      def error(message)
        log_error(message)
      end

      def warn(message)
        log_warning(message)
      end

      private

      def handle_workflow_error(error, step_name, resource_type, start_time)
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.error", {
          step_name: step_name,
          resource_type: resource_type,
          error: error.class.name,
          message: error.message,
          execution_time: execution_time,
        })
      end

      def handle_generic_error(error, step_name, resource_type, start_time)
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.error", {
          step_name: step_name,
          resource_type: resource_type,
          error: error.class.name,
          message: error.message,
          execution_time: execution_time,
        })

        # Print user-friendly error message based on error type
        case error
        when StepLoader::StepNotFoundError
          $stderr.puts "\n❌ Step not found: '#{step_name}'"
          $stderr.puts "   Please check that the step exists in your workflow's steps directory."
          $stderr.puts "   Looking for: steps/#{step_name}.rb or steps/#{step_name}/prompt.md"
        when NoMethodError
          if error.message.include?("undefined method")
            $stderr.puts "\n❌ Step error: '#{step_name}'"
            $stderr.puts "   The step file exists but may be missing the 'call' method."
            $stderr.puts "   Error: #{error.message}"
          end
        else
          $stderr.puts "\n❌ Step failed: '#{step_name}'"
          $stderr.puts "   Error: #{error.message}"
          $stderr.puts "   This may be an issue with the step's implementation."
        end

        # Wrap the original error with context about which step failed
        raise WorkflowExecutor::StepExecutionError.new(
          "Failed to execute step '#{step_name}': #{error.message}",
          step_name: step_name,
          original_error: error,
        )
      end
    end
  end
end
