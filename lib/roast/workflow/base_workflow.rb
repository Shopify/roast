# frozen_string_literal: true

require "raix/chat_completion"
require "raix/function_dispatch"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/string/inflections"
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
        @context_compaction_mutex = Mutex.new

        # Ensure transcript is initialized (from Raix::ChatCompletion)
        self.transcript = [] if transcript.nil?

        # Setup prompt and handlers
        read_sidecar_prompt.then do |prompt|
          next unless prompt

          transcript << { system: prompt }
        end

        # Initialize context manager after transcript is ready
        @context_manager = initialize_context_manager
        Roast::Tools.setup_interrupt_handler(transcript)
        Roast::Tools.setup_exit_handler(self)
      end

      # Override chat_completion to add instrumentation and context management
      def chat_completion(**kwargs)
        # Check and compact context before making the API call
        check_and_compact_context

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

      # Expose managers for state management and testing
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

      def initialize_context_manager
        return unless context_management_enabled?

        context_config = configuration.context_management
        ContextManager.new(
          config: context_config,
          model: model || "gpt-4", # Fallback model
          workflow: self,
        )
      end

      def context_management_enabled?
        configuration&.context_management&.enabled || false
      end

      def calculate_tool_max_tokens
        return unless context_management_enabled?

        context_config = configuration.context_management
        return unless context_config.max_tokens

        # Reserve some tokens for the response and system messages
        # Use a conservative 25% of available tokens for tools
        (context_config.max_tokens * 0.25).to_i
      end

      def tools
        base_tools = super
        return base_tools unless context_management_enabled?

        max_tokens = calculate_tool_max_tokens
        return base_tools unless max_tokens

        # Add max_tokens parameter to tools that support it
        base_tools.map do |tool|
          if tool_supports_max_tokens?(tool[:name])
            add_max_tokens_parameter(tool, max_tokens)
          else
            tool
          end
        end
      end

      def check_and_compact_context
        return unless context_management_enabled? && @context_manager

        @context_compaction_mutex.synchronize do
          if @context_manager.needs_compaction?(transcript)
            self.transcript = @context_manager.compact_transcript(transcript)
          end
        end
      end

      def read_sidecar_prompt
        Roast::Helpers::PromptLoader.load_prompt(self, file)
      end

      def tool_supports_max_tokens?(tool_name)
        # List of tools that support max_tokens parameter for content truncation
        # TODO: If this list grows significantly, consider a more declarative approach
        # such as tools advertising this capability in their schema or class-level attributes
        ["read_file", "search_file", "grep"].include?(tool_name)
      end

      def add_max_tokens_parameter(tool, max_tokens)
        tool = tool.deep_dup

        # Add max_tokens parameter to the tool schema
        tool[:parameters] ||= { type: "object", properties: {} }
        tool[:parameters][:properties] ||= {}
        tool[:parameters][:properties][:max_tokens] = {
          type: "integer",
          description: "Maximum number of tokens to return (for content truncation)",
          minimum: 1,
          default: max_tokens,
        }

        tool
      end
    end
  end
end
