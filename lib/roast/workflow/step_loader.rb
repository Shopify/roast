# frozen_string_literal: true

module Roast
  module Workflow
    # Handles loading and instantiation of workflow steps
    class StepLoader
      DEFAULT_MODEL = "openai/gpt-4o-mini"

      # Custom exception classes
      class StepLoaderError < StandardError
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
      # @return [BaseStep] The loaded step instance
      def load(step_name, step_key: nil)
        name = step_name.is_a?(Roast::ValueObjects::StepName) ? step_name : Roast::ValueObjects::StepName.new(step_name)

        # Get step config for per-step path
        step_config = config_hash[name.to_s] || {}
        per_step_path = step_config["path"]

        # First check for a prompt step (contains spaces)
        if name.plain_text?
          step = Roast::Workflow::PromptStep.new(workflow, name: name.to_s)
          # Use step_key for configuration if provided, otherwise use name
          config_key = step_key || name.to_s
          configure_step(step, config_key)
          return step
        end

        # Look for Ruby file in various locations
        step_file_path = find_step_file(name.to_s, per_step_path)
        if step_file_path
          return load_ruby_step(step_file_path, name.to_s)
        end

        # Look for step directory
        step_directory = find_step_directory(name.to_s, per_step_path)
        unless step_directory
          raise StepNotFoundError.new("Step directory or file not found: #{name}", step_name: name.to_s)
        end

        create_step_instance(Roast::Workflow::BaseStep, name.to_s, step_directory)
      end

      private

      def resolve_path(path)
        return unless path
        return path if Pathname.new(path).absolute?

        File.expand_path(path, context_path)
      end

      # Find a Ruby step file in various locations
      def find_step_file(step_name, per_step_path = nil)
        # Check in per-step path first
        if per_step_path
          resolved_per_step_path = resolve_path(per_step_path)
          custom_rb_path = File.join(resolved_per_step_path, "#{step_name}.rb")
          return custom_rb_path if File.file?(custom_rb_path)
        end

        # Check in phase-specific directory first
        if phase != :steps
          phase_rb_path = File.join(context_path, phase.to_s, "#{step_name}.rb")
          return phase_rb_path if File.file?(phase_rb_path)
        end

        # Check in context path
        rb_file_path = File.join(context_path, "#{step_name}.rb")
        return rb_file_path if File.file?(rb_file_path)

        # Check in shared directory
        shared_rb_path = File.expand_path(File.join(context_path, "..", "shared", "#{step_name}.rb"))
        return shared_rb_path if File.file?(shared_rb_path)

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
      def load_ruby_step(file_path, step_name)
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
        create_step_instance(step_class, step_name, context)
      end

      # Create and configure a step instance
      def create_step_instance(step_class, step_name, context_path)
        step = step_class.new(workflow, name: step_name, context_path: context_path)
        configure_step(step, step_name)
        step
      end

      # Configure a step instance with settings from config_hash
      def configure_step(step, step_name)
        step_config = config_hash[step_name]

        # Always set the model
        step.model = determine_model(step_config)

        # Pass resource to step if supported
        step.resource = workflow.resource if step.respond_to?(:resource=)

        # Apply additional configuration if present
        apply_step_configuration(step, step_config) if step_config.present?
      end

      # Determine which model to use for the step
      def determine_model(step_config)
        step_config&.dig("model") || config_hash["model"] || DEFAULT_MODEL
      end

      # Apply configuration settings to a step
      def apply_step_configuration(step, step_config)
        step.print_response = step_config["print_response"] if step_config.key?("print_response")
        step.json = step_config["json"] if step_config.key?("json")
        step.params = step_config["params"] if step_config.key?("params")
        step.coerce_to = step_config["coerce_to"].to_sym if step_config.key?("coerce_to")
      end
    end
  end
end
