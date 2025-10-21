# frozen_string_literal: true

require "test_helper"
require "open_router"

module Roast
  module Workflow
    class WorkflowRunnerOpenRouterTest < ActiveSupport::TestCase
      def setup
        @workflow_path = File.expand_path("../../fixtures/files/openrouter_workflow.yml", __dir__)
      end

      def test_configure_openrouter_client
        mock_openrouter_client = mock("OpenRouter::Client")
        OpenRouter::Client.stubs(:new).with(access_token: "test_openrouter_token").returns(mock_openrouter_client)

        assert_nothing_raised { WorkflowRunner.new(@workflow_path) }
      end
    end
  end
end
