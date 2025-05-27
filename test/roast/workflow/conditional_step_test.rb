# frozen_string_literal: true

require "test_helper"
require "roast/workflow/conditional_step"

module Roast
  module Workflow
    class ConditionalStepTest < ActiveSupport::TestCase
      setup do
        @workflow = mock("workflow")
        @output = {}
        @workflow.stubs(:output).returns(@output)
        @context_path = "/path/to/workflow.yml"
      end

      test "executes then branch when if condition is true" do
        config = {
          "if" => "{{true}}",
          "then" => ["step1", "step2"],
          "else" => ["step3"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).with(["step1", "step2"]).once

        result = step.call
        assert_equal({ condition_result: true, branch_executed: "then" }, result)
      end

      test "executes else branch when if condition is false" do
        config = {
          "if" => "{{false}}",
          "then" => ["step1"],
          "else" => ["step2", "step3"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).with(["step2", "step3"]).once

        result = step.call
        assert_equal({ condition_result: false, branch_executed: "else" }, result)
      end

      test "executes then branch when unless condition is false" do
        config = {
          "unless" => "{{false}}",
          "then" => ["step1", "step2"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).with(["step1", "step2"]).once

        result = step.call
        assert_equal({ condition_result: true, branch_executed: "then" }, result)
      end

      test "does not execute when unless condition is true" do
        config = {
          "unless" => "{{true}}",
          "then" => ["step1"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).never

        result = step.call
        assert_equal({ condition_result: false, branch_executed: "else" }, result)
      end

      test "evaluates condition from previous step output" do
        @output["check_status"] = { "success" => true }

        # Need to define output method on the workflow instance for evaluation
        @workflow.instance_eval do
          def output
            @output ||= {}
          end
        end
        @workflow.instance_variable_set(:@output, @output)

        config = {
          "if" => "{{output['check_status']['success']}}",
          "then" => ["handle_success"],
          "else" => ["handle_failure"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).with(["handle_success"]).once

        result = step.call
        assert_equal({ condition_result: true, branch_executed: "then" }, result)
      end

      test "handles empty else branch gracefully" do
        config = {
          "if" => "{{false}}",
          "then" => ["step1"],
        }

        step = ConditionalStep.new(
          @workflow,
          config: config,
          name: "test_conditional",
          context_path: @context_path,
        )

        @workflow.expects(:execute_steps).never

        result = step.call
        assert_equal({ condition_result: false, branch_executed: "else" }, result)
      end
    end
  end
end
