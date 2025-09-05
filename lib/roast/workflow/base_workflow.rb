# typed: false
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
      delegate :metadata, :metadata=, to: :metadata_manager
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
        @metadata_manager = MetadataManager.new
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
        request_details = {
          model: step_model || model,
          params: kwargs,
          execution_time: execution_time,
        }
        log_and_raise_error(error, message, request_details, extract_api_context(e))
      rescue => e
        execution_time = Time.now - start_time
        api_context = extract_api_context(e)
        enhanced_message = enhance_error_message(e.message, api_context)
        request_details = {
          model: step_model || model,
          params: kwargs,
          execution_time: execution_time,
        }
        log_and_raise_error(e, enhanced_message, request_details, api_context)
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

      # Expose output and metadata managers for state management
      attr_reader :output_manager, :metadata_manager

      private

      def log_and_raise_error(error, message, request_details, api_context = {})
        ActiveSupport::Notifications.instrument("roast.chat_completion.error", {
          error: error.class.name,
          message: message,
          model: request_details[:model],
          parameters: request_details[:params].except(:openai, :model),
          execution_time: request_details[:execution_time],
          api_url: api_context[:url],
          status_code: api_context[:status],
          response_body: api_context[:response_body],
        })

        # If we have an enhanced message, create a new error with the enhanced message
        if message != error.message
          # Create a new error with the enhanced message
          new_error = error.class.new(message)
          new_error.set_backtrace(error.backtrace) if error.backtrace
          raise new_error
        else
          raise error
        end
      end

      def extract_api_context(error)
        context = {}

        # Handle Faraday errors which have response methods
        if error.respond_to?(:response_status)
          context[:status] = error.response_status
        end

        if error.respond_to?(:response_body)
          context[:response_body] = error.response_body
        end

        if error.respond_to?(:response_headers)
          context[:headers] = error.response_headers
        end

        # Try to extract URL from the error message or response
        if error.respond_to?(:response) && error.response.is_a?(Hash)
          context[:url] = error.response[:url] if error.response[:url]
          context[:status] ||= error.response[:status]
          context[:response_body] ||= error.response[:body]
        end

        # For OpenRouter/OpenAI, try to determine the API endpoint
        if context[:url].nil? && @workflow_configuration
          provider = @workflow_configuration.api_provider
          if provider == :openrouter
            context[:url] = "https://openrouter.ai/api/v1/chat/completions"
          elsif provider == :openai
            context[:url] = "https://api.openai.com/v1/chat/completions"
          end
        end

        context
      end

      def enhance_error_message(original_message, api_context)
        return original_message if api_context.empty?

        # Build an enhanced error message with available context
        enhanced = original_message.dup

        if api_context[:url] && api_context[:status]
          enhanced = "API call to #{api_context[:url]} failed with status #{api_context[:status]}: #{original_message}"
        elsif api_context[:status]
          enhanced = "API call failed with status #{api_context[:status]}: #{original_message}"
        end

        # Add response body details if available and not already in the message
        if api_context[:response_body] && !original_message.include?(api_context[:response_body].to_s)
          body_str = if api_context[:response_body].is_a?(Hash)
            api_context[:response_body].dig("error", "message") || api_context[:response_body].to_json
          else
            api_context[:response_body].to_s
          end

          if body_str && !body_str.empty? && body_str.length < 500
            enhanced += " (Response: #{body_str})"
          end
        end

        enhanced
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
