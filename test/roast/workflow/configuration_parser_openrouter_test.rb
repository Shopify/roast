# frozen_string_literal: true

require "test_helper"
require "mocha/minitest"

module Roast
  module Workflow
    class ConfigurationParserOpenRouterTest < Minitest::Test
      def setup
        @workflow_path = File.expand_path("../../fixtures/files/openrouter_workflow.yml", __dir__)
        mock_openrouter_client = mock
        OpenRouter::Client.stubs(:new).with(access_token: "test_openrouter_token").returns(mock_openrouter_client)
        mock_openrouter_client.stubs(:models).returns(mock_openrouter_client)
        mock_openrouter_client.stubs(:list).returns([])
      end

      def test_configure_openrouter_client
        setup_openrouter_constants

        ConfigurationParser.new(@workflow_path)
      end

      def setup_openrouter_constants
        unless defined?(::OpenRouter)
          Object.const_set(:OpenRouter, Module.new)
        end

        unless defined?(::OpenRouter::Client)
          OpenRouter.const_set(:Client, Class.new)
        end
      end

      def teardown
        OpenRouter::Client.unstub(:new) if OpenRouter::Client.respond_to?(:unstub)
      end
    end
  end
end
