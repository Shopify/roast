# frozen_string_literal: true

module Roast
  module Workflow
    # Handles replay functionality for workflows
    # Manages skipping to specific steps and loading previous state
    class ReplayHandler
      attr_reader :processed

      def initialize(workflow, state_repository: nil)
        @workflow = workflow
        @state_repository = state_repository || FileStateRepository.new
        @processed = false
      end

      def process_replay(steps, replay_option)
        return steps unless replay_option && !@processed

        timestamp, step_name = parse_replay_option(replay_option)
        skip_index = StepFinder.find_index(steps, step_name)

        if skip_index
          $stderr.puts "Replaying from step: #{step_name}#{timestamp ? " (session: #{timestamp})" : ""}"
          @workflow.session_timestamp = timestamp if timestamp && @workflow.respond_to?(:session_timestamp=)
          steps = load_state_and_get_remaining_steps(steps, skip_index, step_name, timestamp)
        else
          $stderr.puts "Step #{step_name} not found in workflow, running from beginning"
        end

        @processed = true
        steps
      end

      def load_state_and_restore(step_name, timestamp: nil)
        state_data = if timestamp
          $stderr.puts "Looking for state before '#{step_name}' in session #{timestamp}..."
          @state_repository.load_state_before_step(@workflow, step_name, timestamp: timestamp)
        else
          $stderr.puts "Looking for state before '#{step_name}' in most recent session..."
          @state_repository.load_state_before_step(@workflow, step_name)
        end

        if state_data
          $stderr.puts "Successfully loaded state with data from previous step"
          restore_workflow_state(state_data)
        else
          session_info = timestamp ? " in session #{timestamp}" : ""
          $stderr.puts "Could not find suitable state data from a previous step to '#{step_name}'#{session_info}."
          $stderr.puts "Will run workflow from '#{step_name}' without prior context."
        end

        state_data
      end

      private

      def parse_replay_option(replay_param)
        return [nil, replay_param] unless replay_param.include?(":")

        timestamp, step_name = replay_param.split(":", 2)

        # Validate timestamp format (YYYYMMDD_HHMMSS_LLL)
        unless timestamp.match?(/^\d{8}_\d{6}_\d{3}$/)
          raise ArgumentError, "Invalid timestamp format: #{timestamp}. Expected YYYYMMDD_HHMMSS_LLL"
        end

        [timestamp, step_name]
      end

      def load_state_and_get_remaining_steps(steps, skip_index, step_name, timestamp)
        load_state_and_restore(step_name, timestamp: timestamp)
        # Always return steps from the requested index, regardless of state loading success
        steps[skip_index..-1]
      end

      def restore_workflow_state(state_data)
        return unless state_data && @workflow

        restore_output(state_data)
        restore_transcript(state_data)
        restore_final_output(state_data)
      end

      def restore_output(state_data)
        return unless state_data.key?(:output)
        return unless @workflow.respond_to?(:output=)

        @workflow.output = state_data[:output]
      end

      def restore_transcript(state_data)
        return unless state_data.key?(:transcript)
        return unless @workflow.respond_to?(:transcript)

        # Transcript is an array from Raix::ChatCompletion
        # We need to clear it and repopulate it
        if @workflow.transcript.respond_to?(:clear) && @workflow.transcript.respond_to?(:<<)
          @workflow.transcript.clear
          state_data[:transcript].each do |message|
            @workflow.transcript << message
          end
        end
      end

      def restore_final_output(state_data)
        return unless state_data.key?(:final_output)

        # Make sure final_output is always handled as an array
        final_output = state_data[:final_output]
        final_output = [final_output] if final_output.is_a?(String)

        if @workflow.respond_to?(:final_output=)
          @workflow.final_output = final_output
        elsif @workflow.instance_variable_defined?(:@final_output)
          @workflow.instance_variable_set(:@final_output, final_output)
        end
      end
    end
  end
end
