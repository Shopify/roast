# frozen_string_literal: true

require "erb"
require "forwardable"
require "roast/workflow/context_path_resolver"

module Roast
  module Workflow
    class BaseStep
      extend Forwardable

      attr_accessor :model, :print_response, :auto_loop, :json, :params, :resource
      attr_reader :workflow, :name, :context_path

      def_delegator :workflow, :append_to_final_output
      def_delegator :workflow, :chat_completion
      def_delegator :workflow, :transcript

      def initialize(workflow, model: "anthropic:claude-3-7-sonnet", name: nil, context_path: nil, auto_loop: true)
        @workflow = workflow
        @model = model
        @name = name || self.class.name.underscore.split("/").last
        @context_path = context_path || ContextPathResolver.resolve(self.class)
        @print_response = false
        @auto_loop = auto_loop
        @json = false
        @params = {}
        @resource = workflow.resource if workflow.respond_to?(:resource)
      end

      def call
        prompt(read_sidecar_prompt)
        chat_completion(print_response:, auto_loop:, json:, params:)
      end

      protected

      def chat_completion(print_response: false, auto_loop: true, json: false, params: {})
        workflow.chat_completion(openai: workflow.openai? && model, loop: auto_loop, model: model, json:, params:).then do |response|
          case response
          in Array
            response.map(&:presence).compact.join("\n")
          else
            response
          end
        end.tap do |response|
          process_output(response, print_response:)
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
    end
  end
end
