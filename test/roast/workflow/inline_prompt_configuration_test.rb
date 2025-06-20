# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InlinePromptConfigurationTest < ActiveSupport::TestCase
      def setup
        @context_path = "/tmp/test"
      end

      private

      def create_workflow_mock(config_hash)
        workflow = mock("workflow")
        workflow.stubs(:output).returns({})
        workflow.stubs(:transcript).returns([])
        workflow.stubs(:resource).returns(nil)
        workflow.stubs(:append_to_final_output)
        workflow.stubs(:openai?).returns(false)
        workflow.stubs(:pause_step_name).returns(nil)
        workflow.stubs(:tools).returns(nil)
        workflow.stubs(:storage_type).returns(nil)

        # Mock the config object
        config = mock("config")
        config_hash.each do |key, value|
          if key != "model" && value.is_a?(Hash) # Step-specific config
            config.stubs(:get_step_config).with(key).returns(value)
          end
        end
        config.stubs(:get_step_config).with(anything).returns({})
        workflow.stubs(:config).returns(config)

        workflow
      end

      test "inline prompt accepts configuration from config hash" do
        config_hash = {
          "analyze the code" => {
            "model" => "gpt-4o",
            "print_response" => true,
            "json" => true,
            "params" => { "temperature" => 0.7 },
          },
        }

        workflow = create_workflow_mock(config_hash)
        executor = WorkflowExecutor.new(workflow, config_hash, @context_path)

        # The inline prompt should receive the configuration
        workflow.expects(:chat_completion).with(
          openai: false,
          model: "gpt-4o",
          json: true,
          params: { "temperature" => 0.7 },
          available_tools: nil,
        ).returns({ "result" => "Test response" })

        result = executor.execute_step("analyze the code")
        assert_equal({ "result" => "Test response" }, result)
      end

      test "inline prompt uses defaults when no configuration provided" do
        # Test with no configuration
        workflow = create_workflow_mock({})
        executor = WorkflowExecutor.new(workflow, {}, @context_path)

        # Now expects loop: false due to new BaseStep behavior
        workflow.expects(:chat_completion).with(
          openai: false,
          model: "gpt-4o-mini", # Default model from StepLoader
          json: false,
          params: {},
          available_tools: nil,
        ).returns("Default response")

        result = executor.execute_step("analyze without config")
        assert_equal "Default response", result
      end

      test "inline prompt respects global model configuration" do
        config_with_global_model = {
          "model" => "claude-3-opus",
        }
        workflow = create_workflow_mock(config_with_global_model)
        executor = WorkflowExecutor.new(workflow, config_with_global_model, @context_path)

        # Now expects loop: false due to new BaseStep behavior
        workflow.expects(:chat_completion).with(
          openai: false,
          model: "claude-3-opus",
          json: false,
          params: {},
          available_tools: nil,
        ).returns("Claude response")

        result = executor.execute_step("use global model")
        assert_equal "Claude response", result
      end

      test "inline prompt step-specific config overrides global config" do
        config_with_both = {
          "model" => "global-model",
          "specific prompt" => {
            "model" => "step-specific-model",
          },
        }
        workflow = create_workflow_mock(config_with_both)
        executor = WorkflowExecutor.new(workflow, config_with_both, @context_path)

        workflow.expects(:chat_completion).with(
          openai: false,
          model: "step-specific-model", # Step-specific overrides global
          json: false,
          params: {},
          available_tools: nil,
        ).returns("Specific response")

        result = executor.execute_step("specific prompt")
        assert_equal "Specific response", result
      end
    end
  end
end
