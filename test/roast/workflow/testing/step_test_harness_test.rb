# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"

module Roast
  module Workflow
    module Testing
      class StepTestHarnessTest < ActiveSupport::TestCase
        # Test step for testing
        class TestStep < BaseStep
          attr_accessor :test_attribute

          def call
            prompt("Test prompt")
            result = chat_completion
            result
          end
        end

        def setup
          @harness = StepTestHarness.new(TestStep)
        end

        test "initializes with step class" do
          assert_kind_of TestStep, @harness.step
          assert_kind_of MockWorkflow, @harness.workflow
          assert_empty @harness.transcript
          assert_empty @harness.output
        end

        test "executes step and returns result" do
          @harness.with_mock_response("Test response")
          result = @harness.execute

          assert result.success?
          assert_equal "Test response", result.result
          assert_equal 2, result.transcript.size
          assert_equal({ user: "Test prompt" }, result.transcript.first)
          assert_equal({ assistant: "Test response" }, result.transcript.last)
        end

        test "captures execution time" do
          @harness.with_mock_response("Test response")
          result = @harness.execute

          assert result.execution_time > 0
          assert_kind_of Float, result.execution_time
        end

        test "handles step execution errors" do
          # Mock the step to raise an error
          @harness.step.stubs(:call).raises(StandardError, "Test error")

          result = @harness.execute

          assert result.failure?
          assert_nil result.result
          assert_kind_of StandardError, result.error
          assert_equal "Test error", result.error.message
        end

        test "configures step attributes" do
          @harness.configure(
            model: "gpt-4",
            print_response: true,
            json: true,
            test_attribute: "test value",
          )

          assert_equal "gpt-4", @harness.step.model
          assert @harness.step.print_response
          assert @harness.step.json
          assert_equal "test value", @harness.step.test_attribute
        end

        test "raises error for invalid configuration attribute" do
          assert_raises(ArgumentError) do
            @harness.configure(invalid_attribute: "value")
          end
        end

        test "adds single mock response" do
          @harness.with_mock_response("Mock response 1")
          result = @harness.execute

          assert_equal "Mock response 1", result.result
        end

        test "adds multiple mock responses" do
          @harness.with_mock_responses("Response 1", "Response 2")

          # Create a step that makes two calls
          test_step = Class.new(BaseStep) do
            def call
              prompt("First prompt")
              first = chat_completion
              prompt("Second prompt")
              second = chat_completion
              [first, second]
            end
          end

          harness = StepTestHarness.new(test_step)
          harness.with_mock_responses("Response 1", "Response 2")
          result = harness.execute

          assert_equal ["Response 1", "Response 2"], result.result
        end

        test "sets available tools" do
          tools = ["grep", "read_file"]
          @harness.with_tools(tools)

          assert_equal tools, @harness.step.available_tools
        end

        test "sets resource" do
          resource = mock("resource")
          @harness.with_resource(resource)

          assert_equal resource, @harness.step.resource
          assert_equal resource, @harness.workflow.resource
        end

        test "adds initial output" do
          initial_output = { "previous_step" => "previous result" }
          @harness.with_initial_output(initial_output)

          assert_equal initial_output, @harness.output
        end

        test "adds initial transcript entries" do
          entries = [
            { user: "Initial prompt" },
            { assistant: "Initial response" },
          ]
          @harness.with_initial_transcript(*entries)

          assert_equal entries, @harness.transcript
        end

        test "chains configuration methods" do
          result = @harness
            .with_mock_response("Test response")
            .with_tools(["grep"])
            .configure(model: "gpt-4")
            .execute

          assert result.success?
          assert_equal "Test response", result.result
          assert_equal ["grep"], @harness.step.available_tools
          assert_equal "gpt-4", @harness.step.model
        end

        test "mock workflow validates expected options" do
          # Test successful validation when options match
          @harness.configure(json: true)
          @harness.with_mock_response({ "result" => "JSON response" }, json: true)

          result = @harness.execute
          assert result.success?
          assert_equal({ "result" => "JSON response" }, result.result)

          # Verify the mock was called with correct options
          assert_equal 1, @harness.workflow.chat_completion_calls.size
          assert_equal true, @harness.workflow.chat_completion_calls.first[:json]

          # Test validation by directly calling workflow method with wrong params
          @harness.workflow.add_mock_response("Response", json: true)

          exception = assert_raises(RuntimeError) do
            # Call with wrong option - should fail validation
            @harness.workflow.chat_completion(json: false)
          end

          assert_match(/Expected json: true, got false/, exception.message)
        end

        test "execution result provides convenience methods" do
          @harness.with_mock_response("Test")
          result = @harness.execute

          assert result.success?
          refute result.failure?
          assert_equal 2, result.transcript_size
          assert result.execution_time > 0
        end
      end

      class MockWorkflowTest < ActiveSupport::TestCase
        def setup
          @workflow = MockWorkflow.new
        end

        test "initializes with default values" do
          assert_empty @workflow.output
          assert_empty @workflow.transcript
          assert_empty @workflow.appended_output
          assert_empty @workflow.chat_completion_calls
          refute @workflow.verbose
          refute @workflow.concise
          assert_nil @workflow.file
          assert_equal "anthropic:claude-opus-4", @workflow.model
        end

        test "initializes with custom options" do
          workflow = MockWorkflow.new(
            { "key" => "value" },
            [{ user: "prompt" }],
            verbose: true,
            concise: true,
            file: "test.rb",
            model: "gpt-4",
          )

          assert_equal({ "key" => "value" }, workflow.output)
          assert_equal [{ user: "prompt" }], workflow.transcript
          assert workflow.verbose
          assert workflow.concise
          assert_equal "test.rb", workflow.file
          assert_equal "gpt-4", workflow.model
        end

        test "appends to final output" do
          @workflow.append_to_final_output("Line 1")
          @workflow.append_to_final_output("Line 2")

          assert_equal ["Line 1", "Line 2"], @workflow.appended_output
        end

        test "chat completion returns mock response" do
          response = @workflow.chat_completion(model: "gpt-4", json: false)

          assert_equal "mock response", response
          assert_equal 1, @workflow.chat_completion_calls.size
          assert_equal({ model: "gpt-4", json: false }, @workflow.chat_completion_calls.first)
          assert_equal({ assistant: "mock response" }, @workflow.transcript.last)
        end

        test "chat completion returns json response when json: true" do
          response = @workflow.chat_completion(json: true)

          assert_equal({ "result" => "mock json response" }, response)
        end

        test "chat completion uses mock responses in order" do
          @workflow.add_mock_response("First response")
          @workflow.add_mock_response("Second response")

          assert_equal "First response", @workflow.chat_completion
          assert_equal "Second response", @workflow.chat_completion
          assert_equal "mock response", @workflow.chat_completion # Falls back to default
        end

        test "openai? returns true for gpt models" do
          @workflow.model = "gpt-4"
          assert @workflow.openai?

          @workflow.model = "gpt-3.5-turbo"
          assert @workflow.openai?
        end

        test "openai? returns false for non-gpt models" do
          @workflow.model = "anthropic:claude-opus-4"
          refute @workflow.openai?

          @workflow.model = nil
          refute @workflow.openai?
        end

        test "responds to expected methods" do
          assert @workflow.respond_to?(:output)
          assert @workflow.respond_to?(:transcript)
          assert @workflow.respond_to?(:resource)
          assert @workflow.respond_to?(:state)
          assert @workflow.respond_to?(:verbose)
          assert @workflow.respond_to?(:concise)
          assert @workflow.respond_to?(:file)
        end

        test "state returns output" do
          @workflow.output["key"] = "value"
          assert_equal @workflow.output, @workflow.state
        end
      end
    end
  end
end
