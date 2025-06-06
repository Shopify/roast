# frozen_string_literal: true

module Roast
  module Workflow
    class BaseStep
      extend Forwardable

      attr_accessor :model, :print_response, :json, :params, :resource, :coerce_to
      attr_reader :workflow, :name, :context_path

      def_delegator :workflow, :append_to_final_output
      def_delegator :workflow, :chat_completion
      def_delegator :workflow, :transcript

      # TODO: is this really the model we want to default to, and is this the right place to set it?
      def initialize(workflow, model: "anthropic:claude-opus-4", name: nil, context_path: nil)
        @workflow = workflow
        @model = model
        @name = name || self.class.name.underscore.split("/").last
        @context_path = context_path || ContextPathResolver.resolve(self.class)
        @print_response = false
        @json = false
        @params = {}
        @coerce_to = nil
        @resource = workflow.resource if workflow.respond_to?(:resource)
      end

      def call
        prompt(read_sidecar_prompt)
        result = chat_completion(print_response:, json:, params:)

        # Apply coercion if configured
        apply_coercion(result)
      end

      protected

      def chat_completion(print_response: nil, json: nil, params: nil)
        # Use instance variables as defaults if parameters are not provided
        print_response = @print_response if print_response.nil?
        json = @json if json.nil?
        params = @params if params.nil?

        workflow.chat_completion(openai: workflow.openai? && model, model: model, json:, params:).tap do |result|
          process_output(result, print_response:)

          begin
            if json
              return nil if result.strip.empty? # Explicitly handle empty string

              return JSON.parse(result)
            end
          rescue JSON::ParserError
            # If JSON parsing fails, leave it as a string
          end
        end
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
          # TODO: use the workflow binding or the step?
          append_to_final_output(ERB.new(File.read(output_path), trim_mode: "-").result(binding))
        elsif print_response
          append_to_final_output(response)
        end
      end

      private

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
