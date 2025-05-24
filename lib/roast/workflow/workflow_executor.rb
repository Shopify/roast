# frozen_string_literal: true

require "English"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"

module Roast
  module Workflow
    # Handles the execution of workflow steps, including orchestration and threading
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
      class CommandExecutionError < WorkflowExecutorError; end
      class StateError < WorkflowExecutorError; end
      class ConfigurationError < WorkflowExecutorError; end

      # Helper method for logging errors
      def log_error(message)
        $stderr.puts "ERROR: #{message}"
      end

      def log_warning(message)
        $stderr.puts "WARNING: #{message}"
      end

      DEFAULT_MODEL = "anthropic:claude-3-7-sonnet"

      attr_reader :workflow, :config_hash, :context_path

      def initialize(workflow, config_hash, context_path)
        @workflow = workflow
        @config_hash = config_hash
        @context_path = context_path
      end

      def execute_steps(workflow_steps)
        workflow_steps.each do |workflow_step|
          case workflow_step
          when Hash
            execute_hash_step(workflow_step)
          when Array
            execute_parallel_steps(workflow_step)
          when String
            execute_string_step(workflow_step)
            Kernel.binding.irb if workflow.pause_step_name == workflow_step # rubocop:disable Lint/Debugger
          else
            raise "Unknown step type: #{workflow_step.inspect}"
          end
        end
      end

      # Interpolates {{expression}} in a string with values from the workflow context
      def interpolate(text)
        return text unless text.is_a?(String) && text.include?("{{") && text.include?("}}")

        # Replace all {{expression}} with their evaluated values
        text.gsub(/\{\{([^}]+)\}\}/) do |match|
          expression = Regexp.last_match(1).strip
          begin
            # Evaluate the expression in the workflow's context
            workflow.instance_eval(expression).to_s
          rescue => e
            # Provide a detailed error message but preserve the original expression
            error_msg = "Error interpolating {{#{expression}}}: #{e.message}. This variable is not defined in the workflow context."
            log_error(error_msg)
            match # Preserve the original expression in the string
          end
        end
      end

      def execute_step(name, exit_on_error: true)
        start_time = Time.now
        # For tests, make sure that we handle this gracefully
        resource_type = workflow.respond_to?(:resource) ? workflow.resource&.type : nil

        ActiveSupport::Notifications.instrument("roast.step.start", {
          step_name: name,
          resource_type: resource_type,
        })

        $stderr.puts "Executing: #{name} (Resource type: #{resource_type || "unknown"})"

        result = if name.starts_with?("$(")
          strip_and_execute(name, exit_on_error: exit_on_error).tap do |output|
            # Add the command and output to the transcript for reference in following steps
            workflow.transcript << { user: "I just executed the following command: ```\n#{name}\n```\n\nHere is the output:\n\n```\n#{output}\n```" }
            workflow.transcript << { assistant: "Noted, thank you." }
          end
        elsif name.include?("*") && (!workflow.respond_to?(:resource) || !workflow.resource)
          # Only use the glob method if we don't have a resource object yet
          # This is for backward compatibility
          glob(name)
        else
          step_object = find_and_load_step(name)
          step_result = step_object.call
          workflow.output[name] = step_result

          # Save state after each step if the workflow supports it
          save_state(name, step_result) if workflow.respond_to?(:session_name) && workflow.session_name

          step_result # Return the result
        end

        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.complete", {
          step_name: name,
          resource_type: resource_type,
          success: true,
          execution_time: execution_time,
          result_size: result.to_s.length,
        })

        result
      rescue WorkflowExecutorError => e
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.error", {
          step_name: name,
          resource_type: resource_type,
          error: e.class.name,
          message: e.message,
          execution_time: execution_time,
        })
        raise
      rescue => e
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.error", {
          step_name: name,
          resource_type: resource_type,
          error: e.class.name,
          message: e.message,
          execution_time: execution_time,
        })

        # Wrap the original error with context about which step failed
        raise StepExecutionError.new("Failed to execute step '#{name}': #{e.message}", step_name: name, original_error: e)
      end

      private

      def execute_hash_step(step)
        # execute a command and store the output in a variable
        name, command = step.to_a.flatten

        # Interpolate variable name if it contains {{}}
        interpolated_name = interpolate(name)

        case name
        when "repeat"
          execute_repeat_step(command)
        when "each"
          # For each steps, the structure is different
          # This is handled in the parser, not here
          raise ConfigurationError, "Invalid 'each' step format. 'as' and 'steps' must be at the same level as 'each'" unless step.key?("as") && step.key?("steps")

          execute_each_step(step)
        else
          if command.is_a?(Hash)
            execute_steps([command])
          else
            # Interpolate command value
            interpolated_command = interpolate(command)

            # Check if this step has exit_on_error configuration
            step_config = config_hash[interpolated_name]
            exit_on_error = step_config.is_a?(Hash) ? step_config.fetch("exit_on_error", true) : true

            workflow.output[interpolated_name] = execute_step(interpolated_command, exit_on_error: exit_on_error)
          end
        end
      end

      def execute_parallel_steps(steps)
        # run steps in parallel, don't proceed until all are done
        steps.map do |sub_step|
          Thread.new { execute_steps([sub_step]) }
        end.each(&:join)
      end

      def execute_string_step(step)
        # Interpolate any {{}} expressions before executing the step
        interpolated_step = interpolate(step)

        # For command steps, check if there's an exit_on_error configuration
        # We need to extract the step name to look up configuration
        if interpolated_step.starts_with?("$(")
          # This is a direct command without a name, so exit_on_error defaults to true
          execute_step(interpolated_step)
        else
          # Check if this step has exit_on_error configuration
          step_config = config_hash[step]
          exit_on_error = step_config.is_a?(Hash) ? step_config.fetch("exit_on_error", true) : true

          execute_step(interpolated_step, exit_on_error: exit_on_error)
        end
      end

      def find_and_load_step(step_name)
        # First check for a prompt step
        if step_name.strip.include?(" ")
          return setup_step(Roast::Workflow::PromptStep, step_name, nil)
        end

        # First check for a ruby file with the step name
        rb_file_path = File.join(context_path, "#{step_name}.rb")
        if File.file?(rb_file_path)
          return load_ruby_step(rb_file_path, step_name)
        end

        # Check in shared directory for ruby file
        shared_rb_path = File.expand_path(File.join(context_path, "..", "shared", "#{step_name}.rb"))
        if File.file?(shared_rb_path)
          return load_ruby_step(shared_rb_path, step_name, File.dirname(shared_rb_path))
        end

        # Continue with existing directory check logic
        step_path = File.join(context_path, step_name)
        step_path = File.expand_path(File.join(context_path, "..", "shared", step_name)) unless File.directory?(step_path)
        raise StepNotFoundError.new("Step directory or file not found: #{step_path}", step_name: step_name) unless File.directory?(step_path)

        setup_step(Roast::Workflow::BaseStep, step_name, step_path)
      end

      def glob(name)
        Dir.glob(name).join("\n")
      end

      def load_ruby_step(file_path, step_name, context_path = File.dirname(file_path))
        $stderr.puts "Requiring step file: #{file_path}"
        begin
          require file_path
        rescue LoadError => e
          raise StepNotFoundError.new("Failed to load step file: #{e.message}", step_name: step_name, original_error: e)
        rescue SyntaxError => e
          raise StepExecutionError.new("Syntax error in step file: #{e.message}", step_name: step_name, original_error: e)
        end
        step_class = step_name.classify.constantize
        setup_step(step_class, step_name, context_path)
      end

      def setup_step(step_class, step_name, context_path)
        step_class.new(workflow, name: step_name, context_path: context_path).tap do |step|
          step_config = config_hash[step_name]

          # Always set the model, even if there's no step_config
          # Use step-specific model if defined, otherwise use workflow default model, or fallback to DEFAULT_MODEL
          step.model = step_config&.dig("model") || config_hash["model"] || DEFAULT_MODEL

          # Pass resource to step if supported
          step.resource = workflow.resource if step.respond_to?(:resource=)

          if step_config.present?
            step.print_response = step_config["print_response"] if step_config["print_response"].present?
            step.loop = step_config["loop"] if step_config["loop"].present?
            step.json = step_config["json"] if step_config["json"].present?
            step.params = step_config["params"] if step_config["params"].present?
          end
        end
      end

      def strip_and_execute(step, exit_on_error: true)
        if step.match?(/^\$\((.*)\)$/)
          # Extract the command from the $(command) syntax
          command = step.strip.match(/^\$\((.*)\)$/)[1]

          # NOTE: We don't need to call interpolate here as it's already been done
          # in execute_string_step before this method is called
          begin
            output = %x(#{command})
            exit_status = $CHILD_STATUS.exitstatus

            if !$CHILD_STATUS.success? && exit_on_error
              raise CommandExecutionError.new("Command exited with non-zero status (#{exit_status})", step_name: command)
            elsif !$CHILD_STATUS.success?
              # When exit_on_error is false, include exit status info in the output
              log_warning("Command '#{command}' exited with non-zero status (#{exit_status}), continuing execution")
              output += "\n[Exit status: #{exit_status}]"
            end

            output
          rescue => e
            if exit_on_error
              raise CommandExecutionError.new("Failed to execute command '#{command}': #{e.message}", step_name: command, original_error: e)
            else
              # Return error information as output when exit_on_error is false
              error_output = "Error executing command: #{e.message}\n[Exit status: error]"
              log_warning("Command '#{command}' failed with error: #{e.message}, continuing execution")
              error_output
            end
          end
        else
          raise ConfigurationError, "Missing closing parentheses in command: #{step}"
        end
      end

      def execute_repeat_step(repeat_config)
        $stderr.puts "Executing repeat step: #{repeat_config.inspect}"

        # Extract parameters from the repeat configuration
        steps = repeat_config["steps"]
        until_condition = repeat_config["until"]
        max_iterations = repeat_config["max_iterations"] || BaseIterationStep::DEFAULT_MAX_ITERATIONS

        # Verify required parameters
        raise ConfigurationError, "Missing 'steps' in repeat configuration" unless steps
        raise ConfigurationError, "Missing 'until' condition in repeat configuration" unless until_condition

        # Create and execute a RepeatStep
        repeat_step = RepeatStep.new(
          workflow,
          steps: steps,
          until_condition: until_condition,
          max_iterations: max_iterations,
          name: "repeat_#{workflow.output.size}",
          context_path: context_path,
        )

        results = repeat_step.call

        # Store results in workflow output
        step_name = "repeat_#{until_condition.gsub(/[^a-zA-Z0-9_]/, "_")}"
        workflow.output[step_name] = results

        # Save state
        save_state(step_name, results) if workflow.respond_to?(:session_name) && workflow.session_name

        results
      end

      def execute_each_step(each_config)
        $stderr.puts "Executing each step: #{each_config.inspect}"

        # Extract parameters from the each configuration
        collection_expr = each_config["each"]
        variable_name = each_config["as"]
        steps = each_config["steps"]

        # Verify required parameters
        raise ConfigurationError, "Missing collection expression in each configuration" unless collection_expr
        raise ConfigurationError, "Missing 'as' variable name in each configuration" unless variable_name
        raise ConfigurationError, "Missing 'steps' in each configuration" unless steps

        # Create and execute an EachStep
        each_step = EachStep.new(
          workflow,
          collection_expr: collection_expr,
          variable_name: variable_name,
          steps: steps,
          name: "each_#{variable_name}",
          context_path: context_path,
        )

        results = each_step.call

        # Store results in workflow output
        step_name = "each_#{variable_name}"
        workflow.output[step_name] = results

        # Save state
        save_state(step_name, results) if workflow.respond_to?(:session_name) && workflow.session_name

        results
      end

      def save_state(step_name, step_result)
        state_repository = FileStateRepository.new

        # Gather necessary data for state
        static_data = workflow.respond_to?(:transcript) ? workflow.transcript.map(&:itself) : []

        # Get output and final_output if available
        output = workflow.respond_to?(:output) ? workflow.output.clone : {}
        final_output = workflow.respond_to?(:final_output) ? workflow.final_output.clone : []

        state_data = {
          step_name: step_name,
          order: output.keys.index(step_name) || output.size,
          transcript: static_data,
          output: output,
          final_output: final_output,
          execution_order: output.keys,
        }

        # Save the state
        state_repository.save_state(workflow, step_name, state_data)
      rescue => e
        # Don't fail the workflow if state saving fails
        log_warning("Failed to save workflow state: #{e.message}")
      end
    end
  end
end
