# frozen_string_literal: true

require "raix"
require "roast/initializers"
require "roast/helpers/function_caching_interceptor"
require "roast/helpers/logger"
require "roast/workflow/base_workflow"

module Roast
  module Workflow
    # Handles initialization of workflow dependencies: initializers, tools, and API clients
    class WorkflowInitializer
      def initialize(configuration)
        @configuration = configuration
      end

      def setup
        load_roast_initializers
        include_tools
        configure_api_client
      end

      private

      def load_roast_initializers
        Roast::Initializers.load_all
      end

      def include_tools
        return unless @configuration.tools.present?

        BaseWorkflow.include(Raix::FunctionDispatch)
        BaseWorkflow.include(Roast::Helpers::FunctionCachingInterceptor) # Add caching support
        BaseWorkflow.include(*@configuration.tools.map(&:constantize))

        post_configure_tools
      end

      def post_configure_tools
        @configuration.tools.each do |tool_name|
          tool_module = tool_name.constantize

          if tool_module.respond_to?(:post_configuration_setup)
            tool_config = @configuration.tool_config(tool_name)
            tool_module.post_configuration_setup(BaseWorkflow, tool_config)
          end
        end
      end

      def configure_api_client
        # Skip if api client is already configured (e.g., by initializers)
        return if api_client_already_configured?

        # Skip if no api_token is provided in the workflow
        return if @configuration.api_token.blank?

        client = case @configuration.api_provider
        when :openrouter
          configure_openrouter_client
        when :openai
          configure_openai_client
        when nil
          # Skip configuration if no api_provider is set
          return
        else
          raise "Unsupported api_provider in workflow configuration: #{@configuration.api_provider}"
        end

        # Validate the client configuration by making a test API call
        validate_api_client(client) if client
      rescue OpenRouter::ConfigurationError, Faraday::UnauthorizedError => e
        error = Roast::AuthenticationError.new("API authentication failed: No API token provided or token is invalid")
        error.set_backtrace(e.backtrace)

        ActiveSupport::Notifications.instrument("roast.workflow.start.error", {
          error: error.class.name,
          message: error.message,
        })

        raise error
      rescue => e
        Roast::Helpers::Logger.error("Error configuring API client: #{e.message}")
        raise e
      end

      def api_client_already_configured?
        case @configuration.api_provider
        when :openrouter
          Raix.configuration.openrouter_client.present?
        when :openai
          Raix.configuration.openai_client.present?
        else
          false
        end
      end

      def client_options
        {
          access_token: @configuration.api_token,
          uri_base: @configuration.uri_base&.to_s,
        }.compact
      end

      def configure_openrouter_client
        $stderr.puts "Configuring OpenRouter client with token from workflow"
        require "open_router"

        client = OpenRouter::Client.new(client_options)

        Raix.configure do |config|
          config.openrouter_client = client
        end
        client
      end

      def configure_openai_client
        $stderr.puts "Configuring OpenAI client with token from workflow"
        require "openai"

        client = OpenAI::Client.new(client_options)

        Raix.configure do |config|
          config.openai_client = client
        end
        client
      end

      def validate_api_client(client)
        # Make a lightweight API call to validate the token
        client.models.list if client.respond_to?(:models)
      end
    end
  end
end
