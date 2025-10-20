# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles loading and instantiation of workflow steps
    class StepLoader
      DEFAULT_MODEL = "gpt-4o-mini"

      # Custom exception classes
      class StepLoaderError < Roast::Error
        attr_reader :step_name, :original_error

        def initialize(message, step_name: nil, original_error: nil)
          @step_name = step_name
          @original_error = original_error
          super(message)
        end
      end

      class StepNotFoundError < StepLoaderError; end
      class StepExecutionError < StepLoaderError; end

      attr_reader :context, :phase

      delegate :workflow, :config_hash, :context_path, to: :context

      def initialize(workflow, config_hash, context_path, phase: :steps)
        # Support both old and new initialization patterns
        @context = if workflow.is_a?(WorkflowContext)
          workflow
        else
          WorkflowContext.new(
            workflow: workflow,
            config_hash: config_hash,
            context_path: context_path,
          )
        end
        @phase = phase
      end

      # Finds and loads a step by name
      #
      # @param step_name [String, StepName] The name of the step to load
      # @param step_key [String] The configuration key for the step (optional)
      # @param options [Hash] Additional options for step loading
      # @return [BaseStep] The loaded step instance
      def load(step_name, step_key: nil, is_last_step: nil, **options)
        name = step_name.is_a?(Roast::ValueObjects::StepName) ? step_name : Roast::ValueObjects::StepName.new(step_name)

        # Get step config for per-step path
        step_config = config_hash[name.to_s] || {}
        per_step_path = step_config["path"]

        # First check for a prompt step (contains spaces)
        if name.plain_text?
          step = StepFactory.create(workflow, name, options)
          # Use step_key for configuration if provided, otherwise use name
          config_key = step_key || name.to_s
          configure_step(step, config_key, is_last_step:)
          return step
        end

        # Look for Ruby or shell script file in various locations
        step_file_info = find_step_file(name.to_s, per_step_path)
        if step_file_info
          case step_file_info[:type]
          when :ruby
            return load_ruby_step(step_file_info[:path], name.to_s, is_last_step:)
          when :shell
            return load_shell_script_step(step_file_info[:path], name.to_s, step_key, is_last_step:)
          end
        end

        # Look for step directory
        step_directory = find_step_directory(name.to_s, per_step_path)
        unless step_directory
          raise StepNotFoundError.new("Step directory or file not found: #{name}", step_name: name.to_s)
        end

        # Use factory to create the appropriate step instance
        step = StepFactory.create(workflow, name, options.merge(context_path: step_directory))
        configure_step(step, name.to_s, is_last_step:)
        step
      end

      private

      def resolve_path(path)
        return unless path
        return path if Pathname.new(path).absolute?

        File.expand_path(path, context_path)
      end

      # Find a Ruby or shell script step file in various locations
      def find_step_file(step_name, per_step_path = nil)
        # Check in per-step path first
        if per_step_path
          resolved_per_step_path = resolve_path(per_step_path)
          custom_rb_path = File.join(resolved_per_step_path, "#{step_name}.rb")
          return { path: custom_rb_path, type: :ruby } if File.file?(custom_rb_path)

          custom_sh_path = File.join(resolved_per_step_path, "#{step_name}.sh")
          return { path: custom_sh_path, type: :shell } if File.file?(custom_sh_path)
        end

        # Check in phase-specific directory first
        if phase != :steps
          phase_rb_path = File.join(context_path, phase.to_s, "#{step_name}.rb")
          return { path: phase_rb_path, type: :ruby } if File.file?(phase_rb_path)

          phase_sh_path = File.join(context_path, phase.to_s, "#{step_name}.sh")
          return { path: phase_sh_path, type: :shell } if File.file?(phase_sh_path)
        end

        # Check in context path
        rb_file_path = File.join(context_path, "#{step_name}.rb")
        return { path: rb_file_path, type: :ruby } if File.file?(rb_file_path)

        sh_file_path = File.join(context_path, "#{step_name}.sh")
        return { path: sh_file_path, type: :shell } if File.file?(sh_file_path)

        # Check in shared directory
        shared_rb_path = File.expand_path(File.join(context_path, "..", "shared", "#{step_name}.rb"))
        return { path: shared_rb_path, type: :ruby } if File.file?(shared_rb_path)

        shared_sh_path = File.expand_path(File.join(context_path, "..", "shared", "#{step_name}.sh"))
        return { path: shared_sh_path, type: :shell } if File.file?(shared_sh_path)

        nil
      end

      # Find a step directory
      def find_step_directory(step_name, per_step_path = nil)
        # Check in per-step path first
        if per_step_path
          resolved_per_step_path = resolve_path(per_step_path)
          custom_step_path = File.join(resolved_per_step_path, step_name)
          return custom_step_path if File.directory?(custom_step_path)
        end

        # Check in phase-specific directory first
        if phase != :steps
          phase_step_path = File.join(context_path, phase.to_s, step_name)
          return phase_step_path if File.directory?(phase_step_path)
        end

        # Check in context path
        step_path = File.join(context_path, step_name)
        return step_path if File.directory?(step_path)

        # Check in shared directory
        shared_path = File.expand_path(File.join(context_path, "..", "shared", step_name))
        return shared_path if File.directory?(shared_path)

        nil
      end

      # Load a Ruby step from a file
      def load_ruby_step(file_path, step_name, is_last_step: nil)
        $stderr.puts "Requiring step file: #{file_path}"

        begin
          require file_path
        rescue LoadError => e
          raise StepNotFoundError.new("Failed to load step file: #{e.message}", step_name: step_name, original_error: e)
        rescue SyntaxError => e
          raise StepExecutionError.new("Syntax error in step file: #{e.message}", step_name: step_name, original_error: e)
        end

        step_class = step_name.classify.constantize
        context = File.dirname(file_path)
        # For Ruby steps, we instantiate the specific class directly
        # Convert step_name to StepName value object
        step_name_obj = Roast::ValueObjects::StepName.new(step_name)
        step = step_class.new(workflow, name: step_name_obj, context_path: context)
        configure_step(step, step_name, is_last_step:)
        step
      end

      # Load a shell script step from a file
      def load_shell_script_step(file_path, step_name, step_key, is_last_step: nil)
        $stderr.puts "Loading shell script step: #{file_path}"

        step_name_obj = Roast::ValueObjects::StepName.new(step_name)

        step = ShellScriptStep.new(
          workflow,
          script_path: file_path,
          name: step_name_obj,
          context_path: File.dirname(file_path),
        )

        configure_step(step, step_key || step_name, is_last_step:)
        step
      end

      # Create and configure a step instance
      def create_step_instance(step_class, step_name, context_path, options = {})
        is_last_step = options[:is_last_step]
        step = StepFactory.create(workflow, step_name, options.merge(context_path: context_path))
        configure_step(step, step_name, is_last_step:)
        step
      end

      # Configure a step instance with settings from config_hash
      def configure_step(step, step_name, is_last_step: nil)
        step_config = config_hash[step_name]

        # Apply global model if no step-specific model is configured
        if config_hash.key?("model") && !step_config&.key?("model")
          step.model = config_hash["model"]
        end

        # Apply step-specific model (overrides global model)
        step.model = step_config["model"] if step_config&.key?("model")

        # Pass resource to step if supported
        step.resource = workflow.resource if step.respond_to?(:resource=)

        # Apply additional configuration if present
        apply_step_configuration(step, step_config) if step_config.present?

        # Set print_response to true for the last step if not already configured
        if is_last_step && !step_config&.key?("print_response")
          step.print_response = true
        end
      end

      # Apply configuration settings to a step
      def apply_step_configuration(step, step_config)
        step.print_response = step_config["print_response"] if step_config.key?("print_response")
        step.json = step_config["json"] if step_config.key?("json")
        step.params = step_config["params"] if step_config.key?("params")
        step.coerce_to = step_config["coerce_to"].to_sym if step_config.key?("coerce_to")

        if step_config.key?("available_tools")
          step.available_tools = step_config["available_tools"]
        end

        # Apply any other configuration attributes that the step supports
        step_config.each do |key, value|
          # Skip keys we've already handled above
          next if ["print_response", "json", "params", "coerce_to", "available_tools"].include?(key)

          # Apply configuration if the step has a setter for this attribute
          setter_method = "#{key}="
          if step.respond_to?(setter_method)
            step.public_send(setter_method, value)
          end
        end
      end
    end
  end
end
