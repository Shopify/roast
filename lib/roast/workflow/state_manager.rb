# frozen_string_literal: true

module Roast
  module Workflow
    # Manages workflow state persistence and restoration
    class StateManager
      attr_reader :workflow, :logger

      def initialize(workflow, logger: nil, state_repository: nil, storage_type: nil)
        @workflow = workflow
        @logger = logger
        @state_repository = state_repository || StateRepositoryFactory.create(storage_type)
      end

      # Save the current state after a step execution
      #
      # @param step_name [String] The name of the step that just completed
      # @param step_result [Object] The result of the step execution
      def save_state(step_name, step_result)
        return unless should_save_state?

        state_data = build_state_data(step_name, step_result)
        @state_repository.save_state(workflow, step_name, state_data)
      rescue => e
        # Don't fail the workflow if state saving fails
        log_warning("Failed to save workflow state: #{e.message}")
      end

      # Check if state should be saved for the current workflow
      #
      # @return [Boolean] true if state should be saved
      def should_save_state?
        workflow.respond_to?(:session_name) && workflow.session_name
      end

      private

      # Build the state data structure for persistence
      def build_state_data(step_name, step_result)
        {
          step_name: step_name,
          order: determine_step_order(step_name),
          transcript: extract_transcript,
          output: extract_output,
          metadata: extract_metadata,
          final_output: extract_final_output,
          execution_order: extract_execution_order,
        }
      end

      # Determine the order of the step in the workflow
      def determine_step_order(step_name)
        return 0 unless workflow.respond_to?(:output)

        workflow.output.keys.index(step_name) || workflow.output.size
      end

      # Extract transcript data if available
      def extract_transcript
        return [] unless workflow.respond_to?(:transcript)

        workflow.transcript.map(&:itself)
      end

      # Extract output data if available
      def extract_output
        return {} unless workflow.respond_to?(:output)

        workflow.output.clone
      end

      # Extract metadata if available
      def extract_metadata
        return {} unless workflow.respond_to?(:metadata)

        workflow.metadata.clone
      end

      # Extract final output data if available
      def extract_final_output
        return [] unless workflow.respond_to?(:final_output)

        workflow.final_output.clone
      end

      # Extract execution order from workflow output
      def extract_execution_order
        return [] unless workflow.respond_to?(:output)

        workflow.output.keys
      end

      # Log a warning message
      def log_warning(message)
        if logger
          logger.warn(message)
        else
          $stderr.puts "WARNING: #{message}"
        end
      end
    end
  end
end
