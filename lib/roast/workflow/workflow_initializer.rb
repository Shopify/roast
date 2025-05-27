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
      end

      def configure_api_client
        # Skip if api client is already configured (e.g., by initializers)
        return if api_client_already_configured?

        # Skip if no api_token is provided in the workflow
        return if @configuration.api_token.blank?

        begin
          case @configuration.api_provider
          when :openrouter
            configure_openrouter_client
          when :openai
            configure_openai_client
          when nil
            # Skip configuration if no api_provider is set
            nil
          else
            raise "Unsupported api_provider in workflow configuration: #{@configuration.api_provider}"
          end
        rescue => e
          Roast::Helpers::Logger.error("Error configuring API client: #{e.message}")
          raise e
        end
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

      def configure_openrouter_client
        $stderr.puts "Configuring OpenRouter client with token from workflow"
        require "open_router"

        Raix.configure do |config|
          config.openrouter_client = OpenRouter::Client.new(access_token: @configuration.api_token)
        end
      end

      def configure_openai_client
        $stderr.puts "Configuring OpenAI client with token from workflow"
        require "openai"

        Raix.configure do |config|
          config.openai_client = OpenAI::Client.new(access_token: @configuration.api_token)
        end
      end
    end
  end
end
