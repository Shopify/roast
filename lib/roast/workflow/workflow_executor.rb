# frozen_string_literal: true

require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"

module Roast
  module Workflow
    # Handles the execution of workflow steps, including orchestration and threading
    class WorkflowExecutor
      DEFAULT_MODEL = "anthropic:claude-3-7-sonnet"

      attr_reader :workflow, :config_hash, :context_path

      def initialize(workflow, config_hash, context_path)
        @workflow = workflow
        @config_hash = config_hash
        @context_path = context_path
      end

      def execute_steps(steps)
        steps.each do |step|
          case step
          when Hash
            execute_hash_step(step)
          when Array
            execute_parallel_steps(step)
          when String
            execute_string_step(step)
          else
            raise "Unknown step type: #{step.inspect}"
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
            # If evaluation fails, provide a more detailed error message but preserve the original expression
            error_msg = "Error interpolating {{#{expression}}}: #{e.message}. This variable is not defined in the workflow context. Please define it before using it in a step name."
            $stderr.puts "ERROR: #{error_msg}"
            match # Return the original match to preserve it in the string
          end
        end
      end

      def execute_step(name)
        start_time = Time.now
        # For tests, make sure that we handle this gracefully
        resource_type = workflow.respond_to?(:resource) ? workflow.resource&.type : nil

        ActiveSupport::Notifications.instrument("roast.step.start", {
          step_name: name,
          resource_type: resource_type,
        })

        $stderr.puts "Executing: #{name} (Resource type: #{resource_type || "unknown"})"

        result = if name.starts_with?("$(")
          strip_and_execute(name).tap do |output|
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

          step_result
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
      rescue => e
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.step.error", {
          step_name: name,
          resource_type: resource_type,
          error: e.class.name,
          message: e.message,
          execution_time: execution_time,
        })
        raise
      end

      private

      def execute_hash_step(step)
        # execute a command and store the output in a variable
        name, command = step.to_a.flatten

        # Interpolate variable name if it contains {{}}
        interpolated_name = interpolate(name)

        if command.is_a?(Hash)
          execute_steps([command])
        else
          # Interpolate command value
          interpolated_command = interpolate(command)
          workflow.output[interpolated_name] = execute_step(interpolated_command)
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
        execute_step(interpolated_step)
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
        raise "Step directory or file not found: #{step_path}" unless File.directory?(step_path)

        setup_step(Roast::Workflow::BaseStep, step_name, step_path)
      end

      def glob(name)
        Dir.glob(name).join("\n")
      end

      def load_ruby_step(file_path, step_name, context_path = File.dirname(file_path))
        $stderr.puts "Requiring step file: #{file_path}"
        require file_path
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

      def strip_and_execute(step)
        if step.match?(/^\$\((.*)\)$/)
          # Extract the command from the $(command) syntax
          command = step.strip.match(/^\$\((.*)\)$/)[1]

          # NOTE: We don't need to call interpolate here as it's already been done
          # in execute_string_step before this method is called
          %x(#{command})
        else
          raise "Missing closing parentheses: #{step}"
        end
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
        $stderr.puts "Warning: Failed to save workflow state: #{e.message}"
      end
    end
  end
end
