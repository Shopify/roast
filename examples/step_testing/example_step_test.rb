# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"
require_relative "example_workflow_step"

module Examples
  module StepTesting
    # Example of how to test a workflow step using the testing framework
    class CodeAnalysisStepTest < Roast::Workflow::Testing::StepTestCase
      test_step CodeAnalysisStep

      test "analyzes code and returns quality score" do
        # Setup mock response
        mock_response = {
          "score" => 0.85,
          "issues" => [
            {
              "type" => "style",
              "severity" => "low",
              "description" => "Line too long",
              "line" => 42,
            },
          ],
          "suggestions" => ["Extract method", "Add comments"],
          "summary" => "Good code quality with minor issues",
        }

        with_mock_response(mock_response)

        # Execute and assert success
        result = assert_step_succeeds

        # Validate output structure
        assert_output_format(:hash)
        assert_required_fields(["score", "issues", "suggestions", "summary", "pass"])

        # Verify the pass/fail logic
        assert result.result["pass"], "Should pass with score 0.85"
      end

      test "fails files below quality threshold" do
        mock_response = {
          "score" => 0.65,
          "issues" => [
            {
              "type" => "logic",
              "severity" => "high",
              "description" => "Potential null reference",
              "line" => 10,
            },
          ],
          "suggestions" => ["Add null checks"],
          "summary" => "Needs improvement",
        }

        with_mock_response(mock_response)
        result = assert_step_succeeds

        refute result.result["pass"], "Should fail with score 0.65"
      end

      test "validates response schema" do
        schema = {
          score: { type: :float },
          issues: [{
            type: { type: :string, enum: ["style", "logic", "performance", "security"] },
            severity: { type: :string, enum: ["low", "medium", "high"] },
            description: { type: :string },
            line: { type: :integer },
          }],
          suggestions: [{ type: :string }],
          summary: { type: :string },
          pass: { type: :boolean },
        }

        mock_response = {
          "score" => 0.9,
          "issues" => [],
          "suggestions" => ["Keep up the good work"],
          "summary" => "Excellent code quality",
        }

        with_mock_response(mock_response)
        assert_output_schema(schema)
      end

      test "handles invalid response format" do
        with_mock_response("Not a JSON response")
        assert_step_fails({}, RuntimeError)
      end

      test "validates score range" do
        with_mock_response({
          "score" => 1.5, # Out of range
          "issues" => [],
          "suggestions" => [],
          "summary" => "Invalid",
        })

        result = assert_step_fails
        assert_match(/Score out of range/, result.error.message)
      end

      test "performance within acceptable limits" do
        mock_response = {
          "score" => 0.8,
          "issues" => [],
          "suggestions" => [],
          "summary" => "Good",
        }

        with_mock_response(mock_response)

        assert_performance(
          execution_time: 2.0, # Should complete within 2 seconds
          api_calls: 1, # Should make exactly 1 API call
          tool_calls: 0, # Should not use any tools
        )
      end

      test "uses appropriate model parameters" do
        with_mock_response({
          "score" => 0.8,
          "issues" => [],
          "suggestions" => [],
          "summary" => "Good",
        })

        execute_step

        # Verify the chat completion was called with correct params
        call = harness.workflow.chat_completion_calls.first
        assert_equal true, call[:json]
        assert_equal 0.2, call[:params][:temperature]
      end

      test "includes file path in prompt" do
        with_resource(Roast::Resources::FileResource.new("test.rb"))
        with_mock_response({
          "score" => 0.8,
          "issues" => [],
          "suggestions" => [],
          "summary" => "Good",
        })

        assert_step_succeeds
        assert_transcript_contains("test.rb")
      end

      test "handles various issue types and severities" do
        mock_response = {
          "score" => 0.7,
          "issues" => [
            { "type" => "style", "severity" => "low", "description" => "Inconsistent spacing", "line" => 5 },
            { "type" => "logic", "severity" => "medium", "description" => "Complex condition", "line" => 20 },
            { "type" => "performance", "severity" => "high", "description" => "N+1 query", "line" => 35 },
            { "type" => "security", "severity" => "high", "description" => "SQL injection risk", "line" => 50 },
          ],
          "suggestions" => ["Refactor", "Add tests", "Review security"],
          "summary" => "Multiple issues found",
        }

        with_mock_response(mock_response)
        result = assert_step_succeeds

        assert_equal 4, result.result["issues"].size
        assert result.result["issues"].any? { |i| i["type"] == "security" && i["severity"] == "high" }
      end

      test "produces deterministic results for same input" do
        mock_response = {
          "score" => 0.85,
          "issues" => [],
          "suggestions" => ["Consistent suggestion"],
          "summary" => "Consistent summary",
        }

        # Setup same response for multiple executions
        3.times { with_mock_response(mock_response) }

        assert_deterministic_output
      end

      test "edge case: empty issues array" do
        mock_response = {
          "score" => 1.0,
          "issues" => [],
          "suggestions" => [],
          "summary" => "Perfect code!",
        }

        with_mock_response(mock_response)
        assert_handles_edge_case(mock_response, :success)
      end

      test "edge case: many issues" do
        issues = 100.times.map do |i|
          {
            "type" => ["style", "logic", "performance", "security"].sample,
            "severity" => ["low", "medium", "high"].sample,
            "description" => "Issue #{i}",
            "line" => i + 1,
          }
        end

        mock_response = {
          "score" => 0.2,
          "issues" => issues,
          "suggestions" => ["Major refactoring needed"],
          "summary" => "Significant quality issues",
        }

        with_mock_response(mock_response)
        result = assert_step_succeeds

        assert_equal 100, result.result["issues"].size
        refute result.result["pass"]
      end

      test "coverage report shows comprehensive testing" do
        # Run several test scenarios to demonstrate coverage
        scenarios = [
          { "score" => 0.9, "issues" => [], "suggestions" => [], "summary" => "Good" },
          {
            "score" => 0.5,
            "issues" => [{ "type" => "logic", "severity" => "high", "description" => "Bad", "line" => 1 }],
            "suggestions" => ["Fix"],
            "summary" => "Poor",
          },
        ]

        scenarios.each do |response|
          with_mock_response(response)
          execute_step
        end

        report = coverage_report
        assert_match(/CodeAnalysisStep/, report)
        assert_match(/Executions: 2/, report)
      end
    end
  end
end
