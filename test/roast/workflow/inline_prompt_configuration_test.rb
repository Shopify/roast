# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InlinePromptConfigurationTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @transcript = []
        @workflow.stubs(:transcript).returns(@transcript)
        @workflow.stubs(:resource).returns(nil)
        @workflow.stubs(:append_to_final_output)
        @workflow.stubs(:openai?).returns(false)
        @workflow.stubs(:pause_step_name).returns(nil)
        @workflow.stubs(:tools).returns(nil)

        @config_hash = {
          "analyze the code" => {
            "model" => "gpt-4o",
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
          model: "gpt-4o",
          json: true,
          params: { "temperature" => 0.7 },
        ).returns('{"result": "Test response"}')

        result = @executor.execute_step("analyze the code")
        assert_equal({ "result" => "Test response" }, result)
      end

      test "inline prompt uses defaults when no configuration provided" do
        # Test with no configuration
        executor = WorkflowExecutor.new(@workflow, {}, @context_path)

        # Now expects loop: false due to new BaseStep behavior
        @workflow.expects(:chat_completion).with(
          openai: false,
          model: "openai/gpt-4o-mini", # Default model
          json: false,
          params: {},
        ).returns("Default response")

        result = executor.execute_step("analyze without config")
        assert_equal "Default response", result
      end

      test "inline prompt respects global model configuration" do
        config_with_global_model = {
          "model" => "claude-3-opus",
        }
        executor = WorkflowExecutor.new(@workflow, config_with_global_model, @context_path)

        # Now expects loop: false due to new BaseStep behavior
        @workflow.expects(:chat_completion).with(
          openai: false,
          model: "claude-3-opus",
          json: false,
          params: {},
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
        executor = WorkflowExecutor.new(@workflow, config_with_both, @context_path)

        @workflow.expects(:chat_completion).with(
          openai: false,
          model: "step-specific-model", # Step-specific overrides global
          json: false,
          params: {},
        ).returns("Specific response")

        result = executor.execute_step("specific prompt")
        assert_equal "Specific response", result
      end
    end
  end
end
