# frozen_string_literal: true

require_relative "workflow_executor"
require_relative "configuration"
require_relative "../helpers/function_caching_interceptor"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "raix"

module Roast
  module Workflow
    class ConfigurationParser
      extend Forwardable

      attr_reader :configuration, :options, :files, :current_workflow

      def_delegator :current_workflow, :output

      def initialize(workflow_path, files = [], options = {})
        @configuration = Configuration.new(workflow_path, options)
        @options = options
        @files = files
        @replay_processed = false # Initialize replay tracking
        load_roast_initializers
        include_tools
        configure_api_client
      end

      def begin!
        start_time = Time.now
        $stderr.puts "Starting workflow..."
        $stderr.puts "Workflow: #{configuration.workflow_path}"
        $stderr.puts "Options: #{options}"

        name = configuration.basename
        context_path = configuration.context_path

        ActiveSupport::Notifications.instrument("roast.workflow.start", {
          workflow_path: configuration.workflow_path,
          options: options,
          name: name,
        })

        if files.any?
          $stderr.puts "WARNING: Ignoring target parameter because files were provided: #{configuration.target}" if configuration.has_target?
          files.each do |file|
            $stderr.puts "Running workflow for file: #{file}"
            setup_workflow(file.strip, name:, context_path:)
            parse(configuration.steps)
          end
        elsif configuration.has_target?
          configuration.target.lines.each do |file|
            $stderr.puts "Running workflow for file: #{file.strip}"
            setup_workflow(file.strip, name:, context_path:)
            parse(configuration.steps)
          end
        else
          # Handle targetless workflow - run once without a specific target
          $stderr.puts "Running targetless workflow"
          setup_workflow(nil, name:, context_path:)
          parse(configuration.steps)
        end
      ensure
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.workflow.complete", {
          workflow_path: configuration.workflow_path,
          success: !$ERROR_INFO,
          execution_time: execution_time,
        })
      end

      private

      def setup_workflow(file, name:, context_path:)
        session_name = configuration.name

        @current_workflow = BaseWorkflow.new(
          file,
          name: name,
          context_path: context_path,
          resource: configuration.resource,
          session_name: session_name,
          configuration: configuration,
        ).tap do |workflow|
          workflow.output_file = options[:output] if options[:output].present?
          workflow.verbose = options[:verbose] if options[:verbose].present?
          workflow.concise = options[:concise] if options[:concise].present?
          workflow.pause_step_name = options[:pause] if options[:pause].present?
        end
      end

      def include_tools
        return unless configuration.tools.present?

        BaseWorkflow.include(Raix::FunctionDispatch)
        BaseWorkflow.include(Roast::Helpers::FunctionCachingInterceptor) # Add caching support
        BaseWorkflow.include(*configuration.tools.map(&:constantize))
      end

      def load_roast_initializers
        Roast::Initializers.load_all
      end

      def configure_api_client
        client = case configuration.api_provider
        when :openrouter
          $stderr.puts "Configuring OpenRouter client with token from workflow"
          require "open_router"

          Raix.configure do |config|
            config.openrouter_client = OpenRouter::Client.new(access_token: configuration.api_token)
          end
        else
          $stderr.puts "Configuring OpenAI client with token from workflow"
          require "openai"

          Raix.configure do |config|
            config.openai_client = OpenAI::Client.new(access_token: configuration.api_token)
          end
        end

        # use an api call to list models as a way to validate our client configuration
        client.models.list
      rescue OpenRouter::ConfigurationError, Faraday::UnauthorizedError => e
        error = Roast::AuthenticationError.new("API authentication failed: No API token provided or token is invalid")
        e.set_backtrace([])

        ActiveSupport::Notifications.instrument("roast.workflow.start.error", {
          error: error.class.name,
          message: error.message,
        })

        raise error
      rescue => e
        Roast::Helpers::Logger.error("Error configuring API client: #{e.message}")
      end

      def load_state_and_update_steps(steps, skip_until, step_name, timestamp)
        state_repository = FileStateRepository.new
        state_data = nil

        if timestamp
          $stderr.puts "Looking for state before '#{step_name}' in session #{timestamp}..."
          state_data = state_repository.load_state_before_step(current_workflow, step_name, timestamp: timestamp)
          if state_data
            $stderr.puts "Successfully loaded state with data from previous step"
            restore_workflow_state(state_data)
          else
            $stderr.puts "Could not find suitable state data from a previous step to '#{step_name}' in session #{timestamp}."
            $stderr.puts "Will run workflow from '#{step_name}' without prior context."
          end
        else
          $stderr.puts "Looking for state before '#{step_name}' in most recent session..."
          state_data = state_repository.load_state_before_step(current_workflow, step_name)
          if state_data
            $stderr.puts "Successfully loaded state with data from previous step"
            restore_workflow_state(state_data)
          else
            $stderr.puts "Could not find suitable state data from a previous step to '#{step_name}'."
            $stderr.puts "Will run workflow from '#{step_name}' without prior context."
          end
        end

        # Always return steps from the requested index, regardless of state loading success
        steps[skip_until..-1]
      end

      # Restore workflow state from loaded state data
      def restore_workflow_state(state_data)
        return unless state_data && current_workflow

        # Restore output
        if state_data[:output] && current_workflow.respond_to?(:output=)
          # Use the setter which will ensure it's a HashWithIndifferentAccess
          current_workflow.output = state_data[:output]
        end

        # Restore transcript if available
        if state_data[:transcript] && current_workflow.respond_to?(:transcript=)
          current_workflow.transcript = state_data[:transcript]
        elsif state_data[:transcript] && current_workflow.respond_to?(:transcript) &&
            current_workflow.transcript.respond_to?(:clear) &&
            current_workflow.transcript.respond_to?(:<<)
          current_workflow.transcript.clear
          state_data[:transcript].each do |message|
            current_workflow.transcript << message
          end
        end

        # Restore final output if available
        if state_data[:final_output]
          # Make sure final_output is always handled as an array
          final_output = state_data[:final_output]
          final_output = [final_output] if final_output.is_a?(String)

          if current_workflow.respond_to?(:final_output=)
            current_workflow.final_output = final_output
          elsif current_workflow.instance_variable_defined?(:@final_output)
            current_workflow.instance_variable_set(:@final_output, final_output)
          end
        end
      end

      def parse(steps)
        return run(steps) if steps.is_a?(String)

        # Handle replay option - skip to the specified step
        if @options[:replay] && !@replay_processed
          replay_param = @options[:replay]
          timestamp = nil
          step_name = replay_param

          # Check if timestamp is prepended (format: timestamp:step_name)
          if replay_param.include?(":")
            timestamp, step_name = replay_param.split(":", 2)

            # Validate timestamp format (YYYYMMDD_HHMMSS_LLL)
            unless timestamp.match?(/^\d{8}_\d{6}_\d{3}$/)
              raise ArgumentError, "Invalid timestamp format: #{timestamp}. Expected YYYYMMDD_HHMMSS_LLL"
            end
          end

          # Find step index by iterating through the steps
          skip_until = find_step_index_in_array(steps, step_name)

          if skip_until
            $stderr.puts "Replaying from step: #{step_name}#{timestamp ? " (session: #{timestamp})" : ""}"
            current_workflow.session_timestamp = timestamp if timestamp
            steps = load_state_and_update_steps(steps, skip_until, step_name, timestamp)
          else
            $stderr.puts "Step #{step_name} not found in workflow, running from beginning"
          end
          @replay_processed = true # Mark that we've processed replay, so we don't do it again in recursive calls
        end

        # Use the WorkflowExecutor to execute the steps
        executor = WorkflowExecutor.new(current_workflow, configuration.config_hash, configuration.context_path)
        executor.execute_steps(steps)

        $stderr.puts "🔥🔥🔥 ROAST COMPLETE! 🔥🔥🔥"

        # Save the final output to the session directory
        save_final_output(current_workflow)

        # Save results to file if specified
        if current_workflow.output_file
          File.write(current_workflow.output_file, current_workflow.final_output)
          $stdout.puts "Results saved to #{current_workflow.output_file}"
        else
          $stdout.puts current_workflow.final_output
        end
      end

      # Delegates to WorkflowExecutor
      def run(name)
        executor = WorkflowExecutor.new(current_workflow, configuration.config_hash, configuration.context_path)
        executor.execute_step(name)
      end

      def find_step_index_in_array(steps_array, step_name)
        steps_array.each_with_index do |step, index|
          case step
          when Hash
            # Could be {name: command} or {name: {substeps}}
            step_key = step.keys.first
            return index if step_key == step_name
          when Array
            # This is a parallel step container, search inside it
            step.each_with_index do |substep, _substep_index|
              case substep
              when Hash
                # Could be {name: command}
                substep_key = substep.keys.first
                return index if substep_key == step_name
              when String
                return index if substep == step_name
              end
            end
          when String
            return index if step == step_name
          end
        end
        nil
      end

      def save_final_output(workflow)
        return unless workflow.respond_to?(:session_name) && workflow.session_name && workflow.respond_to?(:final_output)

        begin
          final_output = workflow.final_output.to_s
          return if final_output.empty?

          state_repository = FileStateRepository.new
          output_file = state_repository.save_final_output(workflow, final_output)
          $stderr.puts "Final output saved to: #{output_file}" if output_file
        rescue => e
          # Don't fail if saving output fails
          $stderr.puts "Warning: Failed to save final output to session: #{e.message}"
        end
      end
    end
  end
end
