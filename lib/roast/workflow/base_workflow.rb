# frozen_string_literal: true

require "raix/chat_completion"
require "raix/function_dispatch"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "active_support/core_ext/hash/indifferent_access"
require "roast/workflow/output_manager"
require "roast/workflow/context_path_resolver"
require "roast/workflow/context_manager"

module Roast
  module Workflow
    class BaseWorkflow
      include Raix::ChatCompletion
      include Raix::FunctionDispatch

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
        :configuration,
        :model

      delegate :api_provider, :openai?, to: :configuration
      delegate :output, :output=, :append_to_final_output, :final_output, to: :output_manager

      def initialize(file = nil, name: nil, context_path: nil, resource: nil, session_name: nil, configuration: nil)
        @file = file
        @name = name || self.class.name.underscore.split("/").last
        @context_path = context_path || ContextPathResolver.resolve(self.class)
        @resource = resource || Roast::Resources.for(file)
        @session_name = session_name || @name
        @session_timestamp = nil
        @configuration = configuration

        # Initialize managers
        @output_manager = OutputManager.new
        @context_manager = initialize_context_manager if context_management_enabled?
        @context_compaction_mutex = Mutex.new

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
          # Check for context compaction before making LLM call (thread-safe)
          @context_compaction_mutex.synchronize do
            check_and_compact_context if @context_manager
          end

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
      rescue => e
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.chat_completion.error", {
          error: e.class.name,
          message: e.message,
          model: step_model || model,
          parameters: kwargs.except(:openai, :model),
          execution_time: execution_time,
        })
        raise
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

      # Override function calling to add max_tokens for tools when context management is enabled
      def function_schemas
        schemas = super
        return schemas unless @context_manager&.config&.enabled

        # Calculate max_tokens for tools based on context management configuration
        tool_max_tokens = calculate_tool_max_tokens

        # Modify schemas for tools that support max_tokens
        schemas.map do |schema|
          if tool_supports_max_tokens?(schema[:name]) && tool_max_tokens
            add_max_tokens_to_schema(schema, tool_max_tokens)
          else
            schema
          end
        end
      end

      # Expose output manager for state management
      attr_reader :output_manager, :context_compaction_mutex

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

      def read_sidecar_prompt
        Roast::Helpers::PromptLoader.load_prompt(self, file)
      end

      def context_management_enabled?
        configuration&.context_management&.enabled
      end

      def initialize_context_manager
        return nil unless configuration&.context_management

        ContextManager.new(
          config: configuration.context_management,
          model: model || configuration.model
        )
      end

      def check_and_compact_context
        return unless @context_manager&.needs_compaction?(transcript)

        original_count = transcript.length
        original_tokens = @context_manager.count_transcript_tokens(transcript)
        
        self.transcript = @context_manager.compact_transcript(transcript)
        
        new_count = transcript.length
        new_tokens = @context_manager.count_transcript_tokens(transcript)
        
        # Log compaction event
        ActiveSupport::Notifications.instrument("roast.context_compaction", {
          strategy: configuration.context_management.strategy,
          original_messages: original_count,
          new_messages: new_count,
          original_tokens: original_tokens,
          new_tokens: new_tokens,
          tokens_saved: original_tokens - new_tokens
        })
      end

      def calculate_tool_max_tokens
        return nil unless @context_manager&.config&.enabled
        
        max_tokens = @context_manager.max_tokens
        threshold = @context_manager.config.threshold
        tool_buffer_factor = 0.75 # Default from PRD
        
        # Calculate available tokens after threshold
        available_tokens = max_tokens * (1 - threshold)
        
        # Apply tool buffer factor
        (available_tokens * tool_buffer_factor).to_i
      end

      def tool_supports_max_tokens?(tool_name)
        # Get base schemas without context management modifications to avoid recursion
        base_schemas = super
        
        # Check if tool already has max_tokens in its base function schema
        tool_schema = base_schemas.find { |schema| schema[:name] == tool_name.to_s }
        return false unless tool_schema
        
        # Check if the tool's parameters include max_tokens
        parameters = tool_schema.dig(:parameters, :properties)
        return false unless parameters
        
        # If tool already has max_tokens parameter, it supports it
        parameters.key?(:max_tokens) || parameters.key?("max_tokens")
      end

      def add_max_tokens_to_schema(schema, max_tokens)
        # Clone the schema to avoid modifying the original
        modified_schema = schema.dup
        
        # Add max_tokens parameter with the calculated value as default
        if modified_schema[:parameters] && modified_schema[:parameters][:properties]
          modified_schema[:parameters] = modified_schema[:parameters].dup
          modified_schema[:parameters][:properties] = modified_schema[:parameters][:properties].dup
          
          # Only add max_tokens if it doesn't already exist
          properties = modified_schema[:parameters][:properties]
          unless properties.key?(:max_tokens) || properties.key?("max_tokens")
            properties[:max_tokens] = {
              type: "integer",
              description: "Maximum tokens to return (will truncate if exceeded)",
              default: max_tokens
            }
          end
        end
        
        modified_schema
      end
    end
  end
end
