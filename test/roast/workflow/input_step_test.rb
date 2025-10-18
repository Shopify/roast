# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InputStepTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(:output).returns({})
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(:state).returns({})
        @workflow.stubs(:respond_to?).with(:state).returns(true)
        @workflow.stubs(:respond_to?).with(:resource).returns(false)
        @workflow.stubs(:model).returns(nil)
      end

      test "initializes with required prompt" do
        config = { "prompt" => "Enter your name:" }
        step = InputStep.new(@workflow, config: config)

        assert_equal "Enter your name:", step.prompt_text
        assert_equal "text", step.type
        assert_equal false, step.required
        assert_nil step.default
        assert_nil step.timeout
      end

      test "raises error if prompt is missing" do
        config = {}

        assert_raises(WorkflowExecutor::ConfigurationError) do
          InputStep.new(@workflow, config: config)
        end
      end

      test "parses all configuration options" do
        config = {
          "prompt" => "Select color:",
          "name" => "favorite_color",
          "type" => "choice",
          "required" => true,
          "default" => "blue",
          "timeout" => 30,
          "options" => ["red", "blue", "green"],
        }

        step = InputStep.new(@workflow, config: config)

        assert_equal "Select color:", step.prompt_text
        assert_equal "favorite_color", step.step_name
        assert_equal "choice", step.type
        assert_equal true, step.required
        assert_equal "blue", step.default
        assert_equal 30, step.timeout
        assert_equal ["red", "blue", "green"], step.options
      end

      test "validates choice type requires options" do
        config = {
          "prompt" => "Select color:",
          "type" => "choice",
        }

        assert_raises(WorkflowExecutor::ConfigurationError) do
          InputStep.new(@workflow, config: config)
        end
      end

      test "validates boolean default values" do
        invalid_defaults = ["invalid", 123, []]

        invalid_defaults.each do |default_value|
          config = {
            "prompt" => "Continue?",
            "type" => "boolean",
            "default" => default_value,
          }

          assert_raises(WorkflowExecutor::ConfigurationError) do
            InputStep.new(@workflow, config: config)
          end
        end
      end

      test "accepts valid boolean default values" do
        valid_defaults = [true, false, "true", "false", "yes", "no"]

        valid_defaults.each do |default_value|
          config = {
            "prompt" => "Continue?",
            "type" => "boolean",
            "default" => default_value,
          }

          step = InputStep.new(@workflow, config: config)
          assert_equal default_value, step.default
        end
      end

      test "stores named input in workflow state" do
        config = {
          "prompt" => "Enter name:",
          "name" => "user_name",
        }

        step = InputStep.new(@workflow, config: config)

        # Mock the UI interaction
        ::CLI::UI.expects(:ask).with("Enter name:", default: nil).returns("John Doe")

        result = step.call

        assert_equal "John Doe", result
        assert_equal "John Doe", @workflow.output["user_name"]
      end

      test "handles required field validation" do
        config = {
          "prompt" => "Enter required field:",
          "required" => true,
        }

        step = InputStep.new(@workflow, config: config)

        # Simulate empty input followed by valid input
        ::CLI::UI.expects(:ask).with("Enter required field:", default: nil).twice.returns("").then.returns("valid input")
        # Don't assert on puts output

        result = step.call

        assert_equal "valid input", result
      end

      test "handles timeout with default value" do
        config = {
          "prompt" => "Enter with timeout:",
          "timeout" => 0.1,
          "default" => "default value",
        }

        step = InputStep.new(@workflow, config: config)

        # Simulate timeout
        ::CLI::UI.stubs(:ask).raises(Timeout::Error)
        # Don't assert on puts output

        result = step.call

        assert_equal "default value", result
      end

      test "handles timeout without default for required field" do
        config = {
          "prompt" => "Enter required with timeout:",
          "timeout" => 0.1,
          "required" => true,
        }

        step = InputStep.new(@workflow, config: config)

        # Simulate timeout
        ::CLI::UI.stubs(:ask).raises(Timeout::Error)
        # Don't assert on puts output

        assert_raises(WorkflowExecutor::ConfigurationError) do
          step.call
        end
      end

      test "prompts for boolean input" do
        config = {
          "prompt" => "Continue?",
          "type" => "boolean",
          "default" => true,
        }

        step = InputStep.new(@workflow, config: config)

        ::CLI::UI.expects(:confirm).with("Continue?", default: true).returns(false)

        result = step.call

        assert_equal false, result
      end

      test "prompts for choice input" do
        config = {
          "prompt" => "Select color:",
          "type" => "choice",
          "options" => ["red", "blue", "green"],
          "default" => "blue",
        }

        step = InputStep.new(@workflow, config: config)

        ::CLI::UI.expects(:ask).with("Select color:", options: ["red", "blue", "green"], default: "blue").returns("red")

        result = step.call

        assert_equal "red", result
      end

      test "prompts for password input" do
        config = {
          "prompt" => "Enter password:",
          "type" => "password",
        }

        step = InputStep.new(@workflow, config: config)

        # Mock the prompt_password_with_echo_off method directly
        step.expects(:prompt_password_with_echo_off).returns("secret123")

        result = step.call

        assert_equal "secret123", result
      end

      test "boolean default conversion" do
        # Test with nil default
        step = InputStep.new(@workflow, config: { "prompt" => "test" })
        assert_nil step.send(:boolean_default)

        # Test with true default
        step = InputStep.new(@workflow, config: { "prompt" => "test", "type" => "boolean", "default" => true })
        assert_equal true, step.send(:boolean_default)

        # Test with "yes" default
        step = InputStep.new(@workflow, config: { "prompt" => "test", "type" => "boolean", "default" => "yes" })
        assert_equal true, step.send(:boolean_default)

        # Test with false default
        step = InputStep.new(@workflow, config: { "prompt" => "test", "type" => "boolean", "default" => false })
        assert_equal false, step.send(:boolean_default)

        # Test with "no" default
        step = InputStep.new(@workflow, config: { "prompt" => "test", "type" => "boolean", "default" => "no" })
        assert_equal false, step.send(:boolean_default)

        # Test with invalid default - this should raise an error during initialization
        assert_raises(WorkflowExecutor::ConfigurationError) do
          InputStep.new(@workflow, config: { "prompt" => "test", "type" => "boolean", "default" => "invalid" })
        end
      end
    end
  end
end
