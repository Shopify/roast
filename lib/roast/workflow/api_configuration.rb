# frozen_string_literal: true

module Roast
  module Workflow
    # Handles API-related configuration including tokens and providers
    class ApiConfiguration
      attr_reader :api_token, :api_provider, :uri_base

      def initialize(config_hash)
        @config_hash = config_hash
        process_api_configuration
      end

      # Check if using OpenRouter
      # @return [Boolean] true if using OpenRouter
      def openrouter?
        Roast::Factories::ApiProviderFactory.openrouter?(@api_provider)
      end

      # Check if using OpenAI
      # @return [Boolean] true if using OpenAI
      def openai?
        Roast::Factories::ApiProviderFactory.openai?(@api_provider)
      end

      # Get the effective API token including environment variables
      # @return [String, nil] The API token
      def effective_token
        @api_token || environment_token
      end

      private

      def process_api_configuration
        extract_api_token
        extract_api_provider
        extract_uri_base
      end

      def extract_api_token
        if @config_hash["api_token"]
          @api_token = ResourceResolver.process_shell_command(@config_hash["api_token"])
        end
      end

      def extract_api_provider
        @api_provider = Roast::Factories::ApiProviderFactory.from_config(@config_hash)
      end

      def extract_uri_base
        if @config_hash["uri_base"]
          @uri_base = ResourceResolver.process_shell_command(@config_hash["uri_base"])
        end
      end

      def environment_token
        if openai?
          ENV["OPENAI_API_KEY"]
        elsif openrouter?
          ENV["OPENROUTER_API_KEY"]
        end
      end
    end
  end
end
