# frozen_string_literal: true

require "roast/value_objects/step_name"
require "roast/workflow/workflow_context"
require_relative "base_step"
require_relative "prompt_step"

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

      attr_reader :context

      delegate :workflow, :config_hash, :context_path, to: :context

      def initialize(workflow, config_hash, context_path)
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
      end

      # Finds and loads a step by name
      #
      # @param step_name [String, StepName] The name of the step to load
      # @return [BaseStep] The loaded step instance
      def load(step_name)
        name = step_name.is_a?(Roast::ValueObjects::StepName) ? step_name : Roast::ValueObjects::StepName.new(step_name)

        # First check for a prompt step (contains spaces)
        if name.plain_text?
          step = Roast::Workflow::PromptStep.new(workflow, name: name.to_s, auto_loop: false)
          configure_step(step, name.to_s)
          return step
        end

        # Look for Ruby file in various locations
        step_file_path = find_step_file(name.to_s)
        if step_file_path
          return load_ruby_step(step_file_path, name.to_s)
        end

        # Look for step directory
        step_directory = find_step_directory(name.to_s)
        unless step_directory
          raise StepNotFoundError.new("Step directory or file not found: #{name}", step_name: name.to_s)
        end

        create_step_instance(Roast::Workflow::BaseStep, name.to_s, step_directory)
      end

      private

      # Find a Ruby step file in various locations
      def find_step_file(step_name)
        # Check in context path
        rb_file_path = File.join(context_path, "#{step_name}.rb")
        return rb_file_path if File.file?(rb_file_path)

        # Check in shared directory
        shared_rb_path = File.expand_path(File.join(context_path, "..", "shared", "#{step_name}.rb"))
        return shared_rb_path if File.file?(shared_rb_path)

        nil
      end

      # Find a step directory
      def find_step_directory(step_name)
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
        step.print_response = step_config["print_response"] if step_config["print_response"].present?
        step.auto_loop = step_config["loop"] if step_config["loop"].present?
        step.json = step_config["json"] if step_config["json"].present?
        step.params = step_config["params"] if step_config["params"].present?
      end
    end
  end
end
