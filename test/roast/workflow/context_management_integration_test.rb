# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_workflow"
require "roast/tools/read_file"

module Roast
  module Workflow
    class ContextManagementIntegrationTest < ActiveSupport::TestCase
      def setup
        @test_file = "/tmp/test_context_integration.txt"
        File.write(@test_file, "Test line\n" * 100)
        
        @config = OpenStruct.new(
          context_management: OpenStruct.new(
            enabled: true,
            max_tokens: 1000,
            threshold: 0.75
          ),
          api_provider: "openai"
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
        assert_includes truncated, "truncated", "Should indicate truncation"
      end

      test "workflow adds max_tokens to tool schemas when enabled" do
        workflow = TestWorkflow.new(nil, configuration: @config)
        schemas = workflow.function_schemas
        
        read_file_schema = schemas.find { |s| s[:name] == "read_file" }
        if read_file_schema
          max_tokens_param = read_file_schema.dig(:parameters, :properties, :max_tokens)
          assert max_tokens_param, "Should add max_tokens parameter"
        end
      end

      test "workflow skips max_tokens when context management disabled" do
        disabled_config = OpenStruct.new(
          context_management: OpenStruct.new(enabled: false),
          api_provider: "openai"
        )
        
        workflow = TestWorkflow.new(nil, configuration: disabled_config)
        assert_nil workflow.send(:calculate_tool_max_tokens)
      end

      private

      class TestWorkflow < BaseWorkflow
        def model
          "gpt-4"
        end
        
        def context_management_enabled?
          configuration&.context_management&.enabled || false
        end
        
        public :function_schemas, :calculate_tool_max_tokens
      end
    end
  end
end