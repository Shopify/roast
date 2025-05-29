# frozen_string_literal: true

require "test_helper"
require "roast/workflow/workflow_executor"

module Roast
  module Workflow
    class InlinePromptConfigurationTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:transcript).returns([])
        @workflow.stubs(:resource).returns(nil)
        @workflow.stubs(:append_to_final_output)
        @workflow.stubs(:openai?).returns(false)
        @workflow.stubs(:pause_step_name).returns(nil)

        @config_hash = {
          "analyze the code" => {
            "model" => "gpt-4o",
            "loop" => false,
            "print_response" => true,
            "json" => true,
            "params" => { "temperature" => 0.7 },
          },
        }

        @context_path = "/tmp/test"
        @executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)
      end

      test "inline prompt accepts configuration from config hash" do
        # The inline prompt should receive the configuration
        @workflow.expects(:chat_completion).with(
          openai: false,
          loop: false,
          model: "gpt-4o",
          json: true,
          params: { "temperature" => 0.7 },
          tools: nil,
        ).returns("Test response")

        result = @executor.execute_step("analyze the code")
        assert_equal "Test response", result
      end

      test "inline prompt uses defaults when no configuration provided" do
        # Test with no configuration
        executor = WorkflowExecutor.new(@workflow, {}, @context_path)

        @workflow.expects(:chat_completion).with(
          openai: false,
          loop: true, # Default auto_loop is true
          model: "openai/gpt-4o-mini", # Default model
          json: false,
          params: {},
          tools: nil,
        ).returns("Default response")

        result = executor.execute_step("analyze without config")
        assert_equal "Default response", result
      end

      test "inline prompt respects global model configuration" do
        config_with_global_model = {
          "model" => "claude-3-opus",
        }
        executor = WorkflowExecutor.new(@workflow, config_with_global_model, @context_path)

        @workflow.expects(:chat_completion).with(
          openai: false,
          loop: true,
          model: "claude-3-opus",
          json: false,
          params: {},
          tools: nil,
        ).returns("Claude response")

        result = executor.execute_step("use global model")
        assert_equal "Claude response", result
      end

      test "inline prompt step-specific config overrides global config" do
        config_with_both = {
          "model" => "global-model",
          "loop" => true,
          "specific prompt" => {
            "model" => "step-specific-model",
            "loop" => false,
          },
        }
        executor = WorkflowExecutor.new(@workflow, config_with_both, @context_path)

        @workflow.expects(:chat_completion).with(
          openai: false,
          loop: false, # Step-specific overrides global
          model: "step-specific-model", # Step-specific overrides global
          json: false,
          params: {},
          tools: nil,
        ).returns("Specific response")

        result = executor.execute_step("specific prompt")
        assert_equal "Specific response", result
      end
    end
  end
end
