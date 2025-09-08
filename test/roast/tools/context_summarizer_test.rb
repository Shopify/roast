# frozen_string_literal: true

require "test_helper"

module Roast
  module Tools
    class ContextSummarizerTest < ActiveSupport::TestCase
      def setup
        @summarizer = ContextSummarizer.new
      end

      test "initializes with default model" do
        assert_equal "o4-mini", @summarizer.model
      end

      test "initializes with custom model" do
        summarizer = ContextSummarizer.new(model: "gpt-4")
        assert_equal "gpt-4", summarizer.model
      end

      test "generate_summary returns nil when workflow_context is nil" do
        result = @summarizer.generate_summary(nil, "Test prompt")
        assert_nil result
      end

      test "generate_summary returns nil when workflow is nil" do
        context = mock
        context.stubs(:workflow).returns(nil)

        result = @summarizer.generate_summary(context, "Test prompt")
        assert_nil result
      end

      test "generate_summary makes chat completion with proper prompt" do
        # Skip this test in CI environments where API calls would fail
        skip "Skipping integration test that requires API setup" if ENV["CI"]

        # Create mock workflow
        workflow = mock
        workflow.stubs(:config).returns({ "description" => "Test workflow for processing data" })
        workflow.stubs(:output).returns({
          "fetch_data" => "Retrieved 100 records from API",
          "process_data" => "Processed records and found 5 anomalies",
        })
        workflow.stubs(:name).returns("data_processor")

        context = mock
        context.stubs(:workflow).returns(workflow)

        # Create a specific instance and stub its method
        summarizer = ContextSummarizer.new
        summarizer.stubs(:chat_completion).returns("The workflow has fetched 100 records and identified 5 anomalies that need to be addressed.")

        # Also need to stub transcript= since it's called in generate_summary
        summarizer.stubs(:transcript=)
        summarizer.stubs(:prompt)

        result = summarizer.generate_summary(context, "Fix the data anomalies")

        assert_equal "The workflow has fetched 100 records and identified 5 anomalies that need to be addressed.", result
      end

      test "generate_summary handles errors gracefully" do
        workflow = mock
        workflow.stubs(:config).returns({})
        workflow.stubs(:output).returns({})
        workflow.stubs(:name).returns("test")

        context = mock
        context.stubs(:workflow).returns(workflow)

        # Create a specific instance and stub to raise error
        summarizer = ContextSummarizer.new
        summarizer.stubs(:transcript=)
        summarizer.stubs(:prompt)
        summarizer.stubs(:chat_completion).raises(Roast::Error.new("API error"))

        result = summarizer.generate_summary(context, "Test prompt")
        assert_nil result
      end

      test "build_context_data extracts relevant workflow information" do
        workflow = mock
        workflow.stubs(:config).returns({ "description" => "Test description" })
        workflow.stubs(:output).returns({ "step1" => "output1", "step2" => "output2" })
        workflow.stubs(:name).returns("test_workflow")

        context_data = @summarizer.send(:build_context_data, workflow)

        assert_equal "Test description", context_data[:workflow_description]
        assert_equal "test_workflow", context_data[:workflow_name]
        assert_equal Dir.pwd, context_data[:working_directory]
        assert_equal 2, context_data[:step_outputs].length
        assert_equal "step1", context_data[:step_outputs][0][:step]
        assert_equal "output1", context_data[:step_outputs][0][:output]
      end

      test "build_summary_prompt creates comprehensive prompt" do
        context_data = {
          workflow_description: "Process customer data",
          workflow_name: "customer_processor",
          working_directory: "/tmp/test",
          step_outputs: [
            { step: "fetch", output: "Fetched 50 customers" },
            { step: "validate", output: "Found 3 invalid records" },
          ],
        }

        agent_prompt = "Fix the invalid customer records"

        prompt = @summarizer.send(:build_summary_prompt, context_data, agent_prompt)

        assert_includes prompt, "Fix the invalid customer records"
        assert_includes prompt, "Process customer data"
        assert_includes prompt, "customer_processor"
        assert_includes prompt, "/tmp/test"
        assert_includes prompt, "Fetched 50 customers"
        assert_includes prompt, "Found 3 invalid records"
        assert_includes prompt, "concise and actionable"
        assert_includes prompt, "No relevant information found in the workflow context."
      end

      test "generate_summary uses its own transcript" do
        workflow = mock
        workflow.stubs(:config).returns({})
        workflow.stubs(:output).returns({})
        workflow.stubs(:name).returns("test")

        context = mock
        context.stubs(:workflow).returns(workflow)

        # Create a specific instance and stub its method
        summarizer = ContextSummarizer.new
        summarizer.stubs(:transcript=)
        summarizer.stubs(:prompt)
        summarizer.stubs(:chat_completion).returns("Summary")

        result = summarizer.generate_summary(context, "Test prompt")
        assert_equal "Summary", result
      end
    end
  end
end
