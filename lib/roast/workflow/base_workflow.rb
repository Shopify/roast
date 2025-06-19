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
        :workflow_configuration,
        :storage_type,
        :context_management_config

      attr_reader :pre_processing_data, :context_manager

      delegate :api_provider, :openai?, to: :workflow_configuration, allow_nil: true
      delegate :output, :output=, :append_to_final_output, :final_output, to: :output_manager
      delegate_missing_to :output

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
        @context_manager = ContextManager.new
        @context_management_config = {}

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
        # Check if retry is configured for API calls
        api_retry_policy = build_api_retry_policy
        
        if api_retry_policy
          retryable = Retryable.new(policy: api_retry_policy)
          retryable.execute { chat_completion_with_instrumentation(**kwargs) }
        else
          chat_completion_with_instrumentation(**kwargs)
        end
      end

      private

      def chat_completion_with_instrumentation(**kwargs)
        start_time = Time.now
        step_model = kwargs[:model]

        with_model(step_model) do
          # Configure context manager if needed
          if @context_management_config.any?
            @context_manager.configure(@context_management_config)
          end

          # Track token usage before API call
          messages = kwargs[:messages] || transcript.flatten.compact
          if @context_management_config[:enabled]
            @context_manager.track_usage(messages)
            @context_manager.check_warnings
          end

          ActiveSupport::Notifications.instrument("roast.chat_completion.start", {
            model: model,
            parameters: kwargs.except(:openai, :model),
          })

          # Clear any previous response
          Thread.current[:chat_completion_response] = nil

          # Call the parent module's chat_completion
          # skip model because it is read directly from the model method
          result = super(**kwargs.except(:model))
          execution_time = Time.now - start_time

          # Extract token usage from the raw response stored by Raix
          raw_response = Thread.current[:chat_completion_response]
          token_usage = extract_token_usage(raw_response) if raw_response

          # Update context manager with actual token usage if available
          if token_usage && @context_management_config[:enabled]
            actual_total = token_usage.dig("total_tokens") || token_usage.dig(:total_tokens)
            @context_manager.update_with_actual_usage(actual_total) if actual_total
          end

          ActiveSupport::Notifications.instrument("roast.chat_completion.complete", {
            success: true,
            model: model,
            parameters: kwargs.except(:openai, :model),
            execution_time: execution_time,
            response_size: result.to_s.length,
            token_usage: token_usage,
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

      def build_api_retry_policy
        return nil unless workflow_configuration&.retry_config
        
        # Check if there's a specific API retry config
        api_config = workflow_configuration.retry_config["api"]
        return nil unless api_config
        
        # Build retry policy with API-specific matchers
        config = api_config.dup
        config[:matcher] ||= {
          type: "composite",
          operator: "any",
          matchers: [
            { type: "rate_limit" },
            { type: "http_status" },
            { type: "error_message", pattern: /timeout|timed out/i }
          ]
        }
        
        RetryPolicyFactory.build(config)
      end

      public

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

      def extract_token_usage(result)
        # Token usage is typically in the response metadata
        # This depends on the API provider's response format
        return unless result.is_a?(Hash) || result.respond_to?(:to_h)

        result_hash = result.is_a?(Hash) ? result : result.to_h
        result_hash.dig("usage") || result_hash.dig(:usage)
      end
    end
  end
end
