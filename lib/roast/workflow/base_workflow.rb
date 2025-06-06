# frozen_string_literal: true

module Roast
  module Workflow
    class BaseWorkflow
      include Raix::ChatCompletion

      attr_accessor :file,
        :concise,
        :output_file,
        :pause_step_name,
        :verbose,
        :name,
        :context_path,
        :resource,
        :session_name,
        :session_timestamp,
        :model,
        :workflow_configuration

      attr_reader :pre_processing_data

      delegate :api_provider, :openai?, to: :workflow_configuration, allow_nil: true
      delegate :output, :output=, :append_to_final_output, :final_output, to: :output_manager

      def initialize(file = nil, name: nil, context_path: nil, resource: nil, session_name: nil, workflow_configuration: nil, pre_processing_data: nil)
        @file = file
        @name = name || self.class.name.underscore.split("/").last
        @context_path = context_path || ContextPathResolver.resolve(self.class)
        @resource = resource || Roast::Resources.for(file)
        @session_name = session_name || @name
        @session_timestamp = nil
        @workflow_configuration = workflow_configuration
        @pre_processing_data = pre_processing_data ? DotAccessHash.new(pre_processing_data).freeze : nil

        # Initialize managers
        @output_manager = OutputManager.new

        # Setup prompt and handlers
        read_sidecar_prompt.then do |prompt|
          next unless prompt

          transcript << { system: prompt }
        end
        Roast::Tools.setup_interrupt_handler(transcript)
        Roast::Tools.setup_exit_handler(self)
      end

      # Override chat_completion to add instrumentation
      def chat_completion(**kwargs)
        start_time = Time.now
        step_model = kwargs[:model]

        with_model(step_model) do
          ActiveSupport::Notifications.instrument("roast.chat_completion.start", {
            model: model,
            parameters: kwargs.except(:openai, :model),
          })

          # Call the parent module's chat_completion
          # skip model because it is read directly from the model method
          result = super(**kwargs.except(:model))
          execution_time = Time.now - start_time

          ActiveSupport::Notifications.instrument("roast.chat_completion.complete", {
            success: true,
            model: model,
            parameters: kwargs.except(:openai, :model),
            execution_time: execution_time,
            response_size: result.to_s.length,
          })
          result
        end
      rescue Faraday::ResourceNotFound => e
        execution_time = Time.now - start_time
        message = e.response.dig(:body, "error", "message") || e.message
        error = Roast::Errors::ResourceNotFoundError.new(message)
        error.set_backtrace(e.backtrace)
        log_and_raise_error(error, message, step_model || model, kwargs, execution_time)
      rescue => e
        execution_time = Time.now - start_time
        log_and_raise_error(e, e.message, step_model || model, kwargs, execution_time)
      end

      def with_model(model)
        previous_model = @model
        @model = model
        yield
      ensure
        @model = previous_model
      end

      def workflow
        self
      end

      # Expose output manager for state management
      attr_reader :output_manager

      # Allow direct access to output values without 'output.' prefix
      def method_missing(method_name, *args, &block)
        if output.respond_to?(method_name)
          output.send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        output.respond_to?(method_name) || super
      end

      private

      def log_and_raise_error(error, message, model, params, execution_time)
        ActiveSupport::Notifications.instrument("roast.chat_completion.error", {
          error: error.class.name,
          message: message,
          model: model,
          parameters: params.except(:openai, :model),
          execution_time: execution_time,
        })

        raise error
      end

      def read_sidecar_prompt
        Roast::Helpers::PromptLoader.load_prompt(self, file)
      end
    end
  end
end
