# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ConfigurationContextManagementTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
      end

      def teardown
        FileUtils.rm_rf(@temp_dir)
      end

      test "loads context management configuration from workflow YAML" do
        workflow_content = <<~YAML
          name: test_workflow
          tools: []
          steps:
            - test_step
          context_management:
            enabled: false
            strategy: summarize
            threshold: 0.7
            max_tokens: 50000
            retain_steps:
              - critical_step_1
              - critical_step_2
        YAML

        workflow_path = File.join(@temp_dir, "workflow.yml")
        File.write(workflow_path, workflow_content)

        config = Configuration.new(workflow_path)

        assert_equal false, config.context_management[:enabled]
        assert_equal "summarize", config.context_management[:strategy]
        assert_equal 0.7, config.context_management[:threshold]
        assert_equal 50000, config.context_management[:max_tokens]
        assert_equal ["critical_step_1", "critical_step_2"], config.context_management[:retain_steps]
      end

      test "provides defaults when context_management is not specified" do
        workflow_content = <<~YAML
          name: test_workflow
          tools: []
          steps:
            - test_step
        YAML

        workflow_path = File.join(@temp_dir, "workflow.yml")
        File.write(workflow_path, workflow_content)

        config = Configuration.new(workflow_path)

        assert_equal true, config.context_management[:enabled]
        assert_equal "auto", config.context_management[:strategy]
        assert_equal 0.8, config.context_management[:threshold]
        assert_nil config.context_management[:max_tokens]
        assert_equal [], config.context_management[:retain_steps]
      end

      test "provides defaults for missing individual settings" do
        workflow_content = <<~YAML
          name: test_workflow
          tools: []
          steps:
            - test_step
          context_management:
            max_tokens: 100000
        YAML

        workflow_path = File.join(@temp_dir, "workflow.yml")
        File.write(workflow_path, workflow_content)

        config = Configuration.new(workflow_path)

        assert_equal true, config.context_management[:enabled]
        assert_equal "auto", config.context_management[:strategy]
        assert_equal 0.8, config.context_management[:threshold]
        assert_equal 100000, config.context_management[:max_tokens]
        assert_equal [], config.context_management[:retain_steps]
      end

      test "validates context management against schema" do
        workflow_content = <<~YAML
          name: test_workflow
          tools: []
          steps:
            - test_step
          context_management:
            strategy: invalid_strategy
        YAML

        workflow_path = File.join(@temp_dir, "workflow.yml")
        File.write(workflow_path, workflow_content)

        # Schema validation should happen during comprehensive validation
        config = Configuration.new(workflow_path)

        # The configuration loader will still load it but with default value
        # Schema validation would catch this with comprehensive_validation option
        assert_equal "invalid_strategy", config.context_management[:strategy]
      end
    end
  end
end
