# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class PromptStepPrintResponseTest < ActiveSupport::TestCase
      class MockWorkflow
        attr_reader :transcript, :appended_output, :chat_completion_calls

        def initialize
          @transcript = []
          @appended_output = []
          @chat_completion_calls = []
        end

        def append_to_final_output(text)
          @appended_output << text
        end

        def chat_completion(**kwargs)
          @chat_completion_calls << kwargs
          # When json: true, return parsed JSON; otherwise return string
          response = kwargs[:json] ? { "result" => "json response" } : "Test response"
          # Simulate adding assistant response to transcript
          @transcript << { assistant: response }
          response
        end

        def openai?
          false
        end

        def tools
          nil
        end

        def model
          nil
        end
      end

      test "print_response true appends response to final output" do
        workflow = MockWorkflow.new

        step = PromptStep.new(workflow, name: "test_step")
        step.print_response = true

        result = step.call

        assert_equal "Test response", result
        assert_equal 1, workflow.appended_output.size
        assert_equal "Test response", workflow.appended_output.first
        assert_equal 1, workflow.chat_completion_calls.size
        assert_equal(
          {
            openai: false,
            model: "gpt-4o-mini",
            json: false,
            params: {},
            available_tools: nil,
          },
          workflow.chat_completion_calls.first,
        )
      end

      test "print_response false does not append response to final output" do
        workflow = MockWorkflow.new

        step = PromptStep.new(workflow, name: "test_step")
        step.print_response = false

        result = step.call

        assert_equal "Test response", result
        assert_empty workflow.appended_output
      end

      test "parameters are passed correctly from instance variables" do
        workflow = MockWorkflow.new

        step = PromptStep.new(workflow, name: "test_step")
        step.print_response = false
        step.json = true
        step.params = { temperature: 0.5 }

        result = step.call

        assert_equal({ "result" => "json response" }, result)
        assert_empty workflow.appended_output
        assert_equal 1, workflow.chat_completion_calls.size
        assert_equal(
          {
            openai: false,
            model: "gpt-4o-mini",
            json: true,
            params: { temperature: 0.5 },
            available_tools: nil,
          },
          workflow.chat_completion_calls.first,
        )
      end
    end
  end
end
