# frozen_string_literal: true

require "raix/chat_completion"
require "raix/function_dispatch"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "active_support/core_ext/hash/indifferent_access"

module Roast
  module Workflow
    class BaseWorkflow
      include Raix::ChatCompletion

      attr_reader :output
      attr_accessor :file,
        :concise,
        :output_file,
        :verbose,
        :name,
        :context_path,
        :resource,
        :session_name,
        :session_timestamp,
        :configuration

      def initialize(file = nil, name: nil, context_path: nil, resource: nil, session_name: nil, configuration: nil)
        @file = file
        @name = name || self.class.name.underscore.split("/").last
        @context_path = context_path || determine_context_path
        @final_output = []
        @output = ActiveSupport::HashWithIndifferentAccess.new
        @resource = resource || Roast::Resources.for(file)
        @session_name = session_name || @name
        @session_timestamp = nil
        @configuration = configuration
        transcript << { system: read_sidecar_prompt }
        Roast::Tools.setup_interrupt_handler(transcript)
        Roast::Tools.setup_exit_handler(self)
      end

      # Custom writer for output to ensure it's always a HashWithIndifferentAccess
      def output=(value)
        @output = if value.is_a?(ActiveSupport::HashWithIndifferentAccess)
          value
        else
          ActiveSupport::HashWithIndifferentAccess.new(value)
        end
      end

      def append_to_final_output(message)
        @final_output << message
      end

      def final_output
        return @final_output if @final_output.is_a?(String)
        return "" if @final_output.nil?

        # Handle array case (expected normal case)
        if @final_output.respond_to?(:join)
          @final_output.join("\n\n")
        else
          # Handle any other unexpected type by converting to string
          @final_output.to_s
        end
      end

      # Override chat_completion to add instrumentation
      def chat_completion(**kwargs)
        start_time = Time.now
        model = kwargs[:openai] || "default"

        ActiveSupport::Notifications.instrument("roast.chat_completion.start", {
          model: model,
          parameters: kwargs.except(:openai),
        })

        result = super(**kwargs)
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.chat_completion.complete", {
          success: true,
          model: model,
          parameters: kwargs.except(:openai),
          execution_time: execution_time,
          response_size: result.to_s.length,
        })

        result
      rescue Faraday::ResourceNotFound => e
        execution_time = Time.now - start_time
        message = e.response.dig(:body, "error", "message") || e.message
        error = Roast::ResourceNotFoundError.new(message)
        e.set_backtrace([])
        log_and_raise_error(error, message, model, kwargs, execution_time)
      rescue NoMethodError => e
        execution_time = Time.now - start_time

        if e.message.include?("undefined method 'chat' for nil")
          error = Roast::AuthenticationError.new("API authentication failed: No API token provided or token is invalid")
          e.set_backtrace([])
          log_and_raise_error(error, error.message, model, kwargs, execution_time)
        else
          log_and_raise_error(e, e.message, model, kwargs, execution_time)
        end
      rescue => e
        execution_time = Time.now - start_time
        log_and_raise_error(e, e.message, model, kwargs, execution_time)
      end

      def workflow
        self
      end

      private

      def log_and_raise_error(error, message, model, params, execution_time)
        ActiveSupport::Notifications.instrument("roast.chat_completion.error", {
          error: error.class.name,
          message: message,
          model: model,
          parameters: params.except(:openai),
          execution_time: execution_time,
        })

        raise error
      end

      # Determine the directory where the actual class is defined, not BaseWorkflow
      def determine_context_path
        # Get the actual class's source file
        klass = self.class

        # Try to get the file path where the class is defined
        path = if klass.name.include?("::")
          # For namespaced classes like Roast::Workflow::Grading::Workflow
          # Convert the class name to a relative path
          class_path = klass.name.underscore + ".rb"
          # Look through load path to find the actual file
          $LOAD_PATH.map { |p| File.join(p, class_path) }.find { |f| File.exist?(f) }
        else
          # Fall back to the current file if we can't find it
          __FILE__
        end

        # Return directory containing the class definition
        File.dirname(path || __FILE__)
      end

      def read_sidecar_prompt
        Roast::Helpers::PromptLoader.load_prompt(self, file)
      end
    end
  end
end
