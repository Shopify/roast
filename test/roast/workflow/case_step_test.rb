# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class CaseStepTest < ActiveSupport::TestCase
      def setup
        @workflow = BaseWorkflow.new
        @workflow_executor = mock("workflow_executor")
        @state_manager = mock("state_manager")
        @state_manager.stubs(:save_state)
      end

      test "evaluates case expression and executes matching when clause" do
        config = {
          "case" => "ruby",
          "when" => {
            "ruby" => ["process_ruby_step"],
            "javascript" => ["process_js_step"],
            "python" => ["process_python_step"],
          },
          "else" => ["process_unknown_step"],
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["process_ruby_step"])

        result = step.call
        assert_equal "ruby", result[:case_value]
        assert_equal "ruby", result[:matched_when]
        assert_equal "ruby", result[:branch_executed]
      end

      test "executes else clause when no when clauses match" do
        config = {
          "case" => "golang",
          "when" => {
            "ruby" => ["process_ruby_step"],
            "javascript" => ["process_js_step"],
            "python" => ["process_python_step"],
          },
          "else" => ["process_unknown_step"],
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["process_unknown_step"])

        result = step.call
        assert_equal "golang", result[:case_value]
        assert_nil result[:matched_when]
        assert_equal "else", result[:branch_executed]
      end

      test "does nothing when no when clauses match and no else clause" do
        config = {
          "case" => "golang",
          "when" => {
            "ruby" => ["process_ruby_step"],
            "javascript" => ["process_js_step"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).never

        result = step.call
        assert_equal "golang", result[:case_value]
        assert_nil result[:matched_when]
        assert_equal "none", result[:branch_executed]
      end

      test "evaluates interpolated case expression" do
        @workflow.output["file_type"] = "javascript"

        config = {
          "case" => "{{ workflow.output.file_type }}",
          "when" => {
            "javascript" => ["process_js_step"],
            "ruby" => ["process_ruby_step"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["process_js_step"])

        result = step.call
        assert_equal "javascript", result[:case_value]
        assert_equal "javascript", result[:matched_when]
      end

      test "evaluates ruby expression in case statement" do
        @workflow.output["count"] = 5

        config = {
          "case" => "{{ workflow.output.count > 3 ? 'high' : 'low' }}",
          "when" => {
            "high" => ["process_high_step"],
            "low" => ["process_low_step"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["process_high_step"])

        result = step.call
        assert_equal "high", result[:case_value]
        assert_equal "high", result[:matched_when]
      end

      test "handles numeric case values" do
        config = {
          "case" => "{{ 42 }}",
          "when" => {
            "42" => ["process_answer_step"],
            "0" => ["process_zero_step"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["process_answer_step"])

        result = step.call
        assert_equal "42", result[:case_value] # Interpolator returns strings
        assert_equal "42", result[:matched_when]
      end

      test "case executor integration" do
        case_config = {
          "case" => "ruby",
          "when" => {
            "ruby" => ["process_ruby_step"],
            "javascript" => ["process_js_step"],
          },
        }

        executor = CaseExecutor.new(@workflow, "/test", @state_manager, @workflow_executor)

        @workflow_executor.expects(:execute_steps).with(["process_ruby_step"])
        @state_manager.expects(:save_state).with(
          "case_ruby",
          has_entries("case_value" => "ruby", "matched_when" => "ruby", "branch_executed" => "ruby"),
        )

        result = executor.execute_case(case_config)
        assert_equal "ruby", result[:case_value]
        assert_equal "ruby", result[:matched_when]
      end

      test "handles bash command in case expression" do
        config = {
          "case" => "$(echo 'production')",
          "when" => {
            "production" => ["deploy_prod_step"],
            "staging" => ["deploy_staging_step"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["deploy_prod_step"])

        result = step.call
        assert_equal "production", result[:case_value]
        assert_equal "production", result[:matched_when]
      end

      test "handles multiple steps in when clause" do
        config = {
          "case" => "ruby",
          "when" => {
            "ruby" => ["lint_ruby", "test_ruby", "build_ruby"],
            "javascript" => ["lint_js", "test_js", "build_js"],
          },
        }

        step = CaseStep.new(
          @workflow,
          config: config,
          name: "case_test",
          context_path: "/test",
          workflow_executor: @workflow_executor,
        )

        @workflow_executor.expects(:execute_steps).with(["lint_ruby", "test_ruby", "build_ruby"])

        result = step.call
        assert_equal "ruby", result[:matched_when]
      end
    end
  end
end
