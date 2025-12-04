# typed: false
# frozen_string_literal: true

module Roast
  module Workflow
    class BaseStep
      attr_accessor :model, :print_response, :json, :params, :resource, :coerce_to, :available_tools
      attr_reader :workflow, :name, :context_path

      delegate :append_to_final_output, :transcript, to: :workflow
      delegate_missing_to :workflow

      def initialize(workflow, model: nil, name: nil, context_path: nil)
        @workflow = workflow
        @model = model || workflow.model || StepLoader::DEFAULT_MODEL
        @name = normalize_name(name)
        @context_path = context_path || ContextPathResolver.resolve(self.class)
        @print_response = false
        @json = false
        @params = {}
        @coerce_to = nil
        @available_tools = nil
        @resource = workflow.resource if workflow.respond_to?(:resource)
      end

      def call
        prompt(read_sidecar_prompt)
        result = chat_completion(print_response:, json:, params:, available_tools:)

        # Apply coercion if configured
        apply_coercion(result)
      end

      protected

      def chat_completion(print_response: nil, json: nil, params: nil, available_tools: nil)
        # Use instance variables as defaults if parameters are not provided
        print_response = @print_response if print_response.nil?
        json = @json if json.nil?
        params = @params if params.nil?
        available_tools = @available_tools if available_tools.nil?

        result = workflow.chat_completion(openai: workflow.openai? && model, model: model, json:, params:, available_tools:)
        process_output(result, print_response:)

        result
      end

      def prompt(text)
        transcript << { user: text }
      end

      def read_sidecar_prompt
        # For file resources, use the target path for prompt selection
        # For other resource types, fall back to workflow.file
        target_path = if resource&.type == :file
          resource.target
        else
          workflow.file
        end

        Roast::Helpers::PromptLoader.load_prompt(self, target_path)
      end

      def process_output(response, print_response:)
        output_path = File.join(context_path, "output.txt")
        if File.exist?(output_path) && print_response
          # Deep wrap the response for template access
          template_response = deep_wrap_for_templates(response)

          # Debug output
          if template_response.is_a?(DotAccessHash) && template_response.recommendations&.is_a?(Array)
            Roast::Log.debug("DEBUG: recommendations array has #{template_response.recommendations.size} items")
            Roast::Log.debug("DEBUG: first item class: #{template_response.recommendations.first.class}") if template_response.recommendations.first
          end

          # Create a binding that includes the wrapped response
          template_binding = binding
          template_binding.local_variable_set(:response, template_response)

          append_to_final_output(ERB.new(File.read(output_path), trim_mode: "-").result(template_binding))
        elsif print_response
          append_to_final_output(response)
        end
      end

      private

      def normalize_name(name)
        return name if name.is_a?(Roast::ValueObjects::StepName)

        name_value = name || self.class.name.underscore.split("/").last
        Roast::ValueObjects::StepName.new(name_value)
      end

      # Deep wrap response for ERB templates
      # This creates a new structure where:
      # - Hashes are wrapped in DotAccessHash
      # - Arrays are cloned with their Hash elements wrapped
      def deep_wrap_for_templates(obj)
        case obj
        when Hash
          # Convert the hash to a new hash with wrapped values
          wrapped_hash = {}
          obj.each do |key, value|
            wrapped_hash[key] = deep_wrap_for_templates(value)
          end
          DotAccessHash.new(wrapped_hash)
        when Array
          # Create a new array with wrapped elements
          # This allows the template to use dot notation on array elements
          obj.map { |item| deep_wrap_for_templates(item) }
        else
          obj
        end
      end

      def apply_coercion(result)
        case @coerce_to
        when :boolean
          # Simple boolean coercion - empty string is false
          return false if result.nil? || result == ""

          !!result
        when :llm_boolean
          # Use LLM boolean coercer for natural language responses
          LlmBooleanCoercer.coerce(result)
        when :iterable
          # Ensure result is iterable
          return result if result.respond_to?(:each)

          # Try to parse as JSON array first
          if result.is_a?(String) && result.strip.start_with?("[")
            begin
              parsed = JSON.parse(result)
              return parsed if parsed.is_a?(Array)
            rescue JSON::ParserError
              # Fall through to split by newlines
            end
          end

          result.to_s.split("\n")
        else
          # Unknown or nil coercion type, return as-is
          result
        end
      end
    end
  end
end
