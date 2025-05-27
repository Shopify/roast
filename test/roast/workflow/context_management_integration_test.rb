# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_workflow"
require "roast/tools/read_file"

module Roast
  module Workflow
    # Test configuration class to replace OpenStruct in tests
    class TestConfiguration
      attr_accessor :context_management, :api_provider

      def initialize(context_management:, api_provider:)
        @context_management = context_management
        @api_provider = api_provider
      end
    end

    class ContextManagementIntegrationTest < ActiveSupport::TestCase
      def setup
        @test_file = "/tmp/test_context_integration.txt"
        File.write(@test_file, "Test line\n" * 100)

        @config = TestConfiguration.new(
          context_management: Roast::Workflow::ContextManagementConfig.new(
            enabled: true,
            max_tokens: 1000,
            threshold: 0.75,
          ),
          api_provider: "openai",
        )

        Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
      end

      def teardown
        File.delete(@test_file) if File.exist?(@test_file)
        Roast::Helpers::PromptLoader.unstub(:load_prompt)
      end

      test "tools respect max_tokens when provided" do
        truncated = Roast::Tools::ReadFile.call(@test_file, max_tokens: 50)
        full = File.read(@test_file)

        assert truncated.length < full.length, "Should truncate with max_tokens"
        assert_includes truncated, "[...truncated...]", "Should indicate truncation"
      end

      test "workflow adds max_tokens to tool schemas when enabled" do
        workflow = TestWorkflow.new(nil, configuration: @config)

        # Test the helper methods directly since tool schema modification is complex to test
        assert workflow.tool_supports_max_tokens?("read_file")
        assert workflow.tool_supports_max_tokens?("search_file")
        assert workflow.tool_supports_max_tokens?("grep")
        refute workflow.tool_supports_max_tokens?("unknown_tool")

        # Test that add_max_tokens_parameter works correctly
        sample_tool = {
          name: "read_file",
          parameters: { type: "object", properties: { path: { type: "string" } } },
        }

        modified_tool = workflow.add_max_tokens_parameter(sample_tool, 250)
        max_tokens_param = modified_tool.dig(:parameters, :properties, :max_tokens)

        assert max_tokens_param, "Should add max_tokens parameter"
        assert_equal "integer", max_tokens_param[:type]
        assert_equal 250, max_tokens_param[:default]
        assert_equal 1, max_tokens_param[:minimum]
      end

      test "workflow skips max_tokens when context management disabled" do
        disabled_config = TestConfiguration.new(
          context_management: Roast::Workflow::ContextManagementConfig.new(enabled: false),
          api_provider: "openai",
        )

        workflow = TestWorkflow.new(nil, configuration: disabled_config)
        assert_nil workflow.calculate_tool_max_tokens
      end

      test "workflow calculates tool max tokens when enabled" do
        workflow = TestWorkflow.new(nil, configuration: @config)
        max_tokens = workflow.calculate_tool_max_tokens

        # Should be 25% of 1000 = 250
        assert_equal 250, max_tokens
      end

      class TestWorkflow < BaseWorkflow
        include Roast::Tools::ReadFile

        def model
          "gpt-4"
        end

        def context_management_enabled?
          configuration&.context_management&.enabled || false
        end

        public :tools, :calculate_tool_max_tokens, :tool_supports_max_tokens?, :add_max_tokens_parameter
      end
    end
  end
end
