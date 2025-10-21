# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Coordinates the execution of different types of steps
    #
    # This class is responsible for routing steps to their appropriate executors
    # based on the step type. It acts as a central dispatcher that determines
    # which execution strategy to use for each step.
    #
    # Current Architecture:
    # - WorkflowExecutor.execute_steps still handles basic routing for backward compatibility
    # - This coordinator is used by WorkflowExecutor.execute_step for named steps
    # - Some step types (parallel) use the StepExecutorFactory pattern
    # - Other step types use direct execution methods
    #
    # TODO: Future refactoring should move all execution logic from WorkflowExecutor
    # to this coordinator and use the factory pattern consistently for all step types.
    class StepExecutorCoordinator
      def initialize(context:, dependencies:)
        @context = context
        @dependencies = dependencies
      end

      # Execute a list of steps
      def execute_steps(workflow_steps)
        workflow_steps.each_with_index do |step, index|
          is_last_step = (index == workflow_steps.length - 1)
          case step
          when Hash
            execute(step, is_last_step:)
          when Array
            execute(step, is_last_step:)
          when String
            execute(step, is_last_step:)
            # Handle pause after string steps
            if @context.workflow.pause_step_name == step
              Kernel.binding.irb # rubocop:disable Lint/Debugger
            end
          else
            execute_custom_step(step, is_last_step: is_last_step)
          end
        end
      end

      # Execute a single step (alias for compatibility)
      def execute_step(step, **options)
        execute(step, **options)
      end

      # Execute a step based on its type
      # @param step [String, Hash, Array] The step to execute
      # @param options [Hash] Execution options
      # @return [Object] The result of the step execution
      def execute(step, **options)
        step_type = StepTypeResolver.resolve(step, @context)
        step_name = StepTypeResolver.extract_name(step)

        Thread.current[:current_step_name] = step_name if step_name
        Thread.current[:workflow_metadata] = @context.workflow.metadata

        unless options[:retries]
          options[:retries] = @context.config_hash[step_name]&.fetch("retries", 0) || 0
        end

        case step_type
        when StepTypeResolver::COMMAND_STEP
          # Command steps should also go through interpolation
          execute_string_step(step, options)
        when StepTypeResolver::AGENT_STEP
          execute_agent_step(step, options)
        when StepTypeResolver::GLOB_STEP
          execute_glob_step(step, options)
        when StepTypeResolver::ITERATION_STEP
          execute_iteration_step(step, options)
        when StepTypeResolver::CONDITIONAL_STEP
          execute_conditional_step(step, options)
        when StepTypeResolver::CASE_STEP
          execute_case_step(step, options)
        when StepTypeResolver::INPUT_STEP
          execute_input_step(step, options)
        when StepTypeResolver::HASH_STEP
          execute_hash_step(step, options)
        when StepTypeResolver::PARALLEL_STEP
          # Use factory for parallel steps
          executor = StepExecutorFactory.for(step, workflow_executor)
          executor.execute(step)
        when StepTypeResolver::STRING_STEP
          execute_string_step(step, options)
        else
          execute_standard_step(step, options)
        end
      end

      private

      attr_reader :context, :dependencies

      def workflow_executor
        dependencies[:workflow_executor]
      end

      def interpolator
        dependencies[:interpolator]
      end

      def command_executor
        dependencies[:command_executor]
      end

      def iteration_executor
        dependencies[:iteration_executor]
      end

      def conditional_executor
        dependencies[:conditional_executor]
      end

      def case_executor
        @case_executor ||= dependencies[:case_executor] || CaseExecutor.new(
          context.workflow,
          context.context_path,
          dependencies[:state_manager] || dependencies[:workflow_executor].state_manager,
          workflow_executor,
        )
      end

      def input_executor
        @input_executor ||= dependencies[:input_executor] || InputExecutor.new(
          context.workflow,
          context.context_path,
          dependencies[:state_manager] || dependencies[:workflow_executor].state_manager,
          workflow_executor,
        )
      end

      def error_handler
        dependencies[:error_handler]
      end

      def step_loader
        dependencies[:step_loader]
      end

      def state_manager
        dependencies[:state_manager]
      end

      def execute_command_step(step, options)
        exit_on_error = options.fetch(:exit_on_error, true)
        resource_type = @context.resource_type
        step_key = options[:step_key]
        display_name = step_key || step
        retries = options.fetch(:retries, 0)

        error_handler.with_error_handling(display_name, resource_type: resource_type, retries:) do
          $stderr.puts "Executing: #{display_name} (Resource type: #{resource_type || "unknown"})"

          begin
            output = command_executor.execute(step, exit_on_error: exit_on_error)

            # Print command output in verbose mode
            workflow = context.workflow
            if workflow.verbose
              $stderr.puts "Command output:"
              $stderr.puts output
              $stderr.puts
            end

            # Add to transcript
            workflow.transcript << {
              user: "I just executed the following command: ```\n#{step}\n```\n\nHere is the output:\n\n```\n#{output}\n```",
            }
            workflow.transcript << { assistant: "Noted, thank you." }

            output
          rescue CommandExecutor::CommandExecutionError => e
            # Print user-friendly error message
            $stderr.puts "\n❌ Command failed: #{display_name}"
            $stderr.puts "   Exit status: #{e.exit_status}" if e.exit_status

            # Show command output if available
            if e.respond_to?(:output) && e.output && !e.output.strip.empty?
              $stderr.puts "   Command output:"
              e.output.strip.split("\n").each do |line|
                $stderr.puts "     #{line}"
              end
            elsif workflow && !workflow.verbose
              $stderr.puts "   To see the command output, run with --verbose flag."
            end

            $stderr.puts "   This typically means the command returned an error.\n"
            raise
          end
        end
      end

      def execute_agent_step(step, options = {})
        # Extract the step name without the ^ prefix
        step_name = StepTypeResolver.extract_name(step)

        # Load and execute the agent step
        merged_options = options.merge(
          exit_on_error: options.fetch(:exit_on_error) { context.exit_on_error?(step) },
          agent_type: :coding_agent,
        )
        execute_custom_step(step_name, **merged_options)
      end

      def execute_glob_step(step, options = {})
        Dir.glob(step).join("\n")
      end

      def execute_iteration_step(step, options = {})
        name = step.keys.first
        command = step[name]

        case name
        when "repeat"
          iteration_executor.execute_repeat(command)
        when "each"
          validate_each_step!(step)
          iteration_executor.execute_each(step)
        end
      end

      def execute_conditional_step(step, options = {})
        conditional_executor.execute_conditional(step)
      end

      def execute_case_step(step, options = {})
        case_executor.execute_case(step)
      end

      def execute_input_step(step, options = {})
        input_executor.execute_input(step["input"])
      end

      def execute_hash_step(step, options = {})
        name, command = step.to_a.flatten
        interpolated_name = interpolator.interpolate(name)

        if command.is_a?(Hash)
          execute_steps([command])
        else
          interpolated_command = interpolator.interpolate(command)
          exit_on_error = context.exit_on_error?(interpolated_name)

          # Execute the command directly using the appropriate executor
          # Pass the original key name for configuration lookup
          # Merge options to preserve is_last_step
          result = execute(interpolated_command, { exit_on_error:, step_key: interpolated_name }.merge(options))
          context.workflow.output[interpolated_name] = result
          result
        end
      end

      def execute_string_step(step, options = {})
        # Check for glob before interpolation
        if StepTypeResolver.glob_step?(step, context)
          return execute_glob_step(step)
        end

        interpolated_step = interpolator.interpolate(step)

        if StepTypeResolver.command_step?(interpolated_step)
          # Command step - execute directly, preserving any passed options including step_key
          exit_on_error = options.fetch(:exit_on_error, true)
          step_key = options[:step_key]
          retries = options[:retries] || 0
          execute_command_step(interpolated_step, { exit_on_error:, step_key:, retries: })
        else
          exit_on_error = options.fetch(:exit_on_error, context.exit_on_error?(step))
          execute_standard_step(interpolated_step, options.merge(exit_on_error:))
        end
      end

      def execute_standard_step(step, options)
        exit_on_error = options.fetch(:exit_on_error, true)
        step_key = options[:step_key]
        is_last_step = options[:is_last_step]
        execute_custom_step(step, exit_on_error:, step_key:, is_last_step:)
      end

      def validate_each_step!(step)
        unless step.key?("as") && step.key?("steps")
          raise WorkflowExecutor::ConfigurationError,
            "Invalid 'each' step format. 'as' and 'steps' must be at the same level as 'each'"
        end
      end

      def execute_custom_step(name, step_key: nil, **options)
        resource_type = @context.workflow.respond_to?(:resource) ? @context.workflow.resource&.type : nil
        retries = options[:retries] || 0

        error_handler.with_error_handling(name, resource_type: resource_type, retries:) do
          $stderr.puts "Executing: #{name} (Resource type: #{resource_type || "unknown"})"

          # Use step_key for loading if provided, otherwise use name
          load_key = step_key || name
          is_last_step = options[:is_last_step]
          step_object = step_loader.load(name, exit_on_error: false, step_key: load_key, is_last_step:, **options)
          step_result = step_object.call

          # Store result in workflow output
          # Use step_key for output storage if provided (for hash steps)
          output_key = step_key || name
          @context.workflow.output[output_key] = step_result

          # Save state after each step
          state_manager.save_state(name, step_result)

          step_result
        end
      end
    end
  end
end
