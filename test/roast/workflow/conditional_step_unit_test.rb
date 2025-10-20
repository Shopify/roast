# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ConditionalStepUnitTest < ActiveSupport::TestCase
      test "executes then branch for simple true condition" do
        workflow = Object.new
        workflow.define_singleton_method(:output) { {} }
        workflow.define_singleton_method(:model) { nil }

        # Mock instance_eval to return true
        workflow.define_singleton_method(:instance_eval) do |expr|
          expr == "true"
        end

        workflow_executor = Object.new
        workflow_executor.define_singleton_method(:execute_steps) { |steps| @executed_steps = steps }
        workflow_executor.define_singleton_method(:executed_steps) { @executed_steps }

        config = {
          "if" => "{{true}}",
          "then" => ["step1", "step2"],
          "else" => ["step3"],
        }

        step = ConditionalStep.new(
          workflow,
          config: config,
          name: "test_conditional",
          context_path: "/test/path",
          workflow_executor: workflow_executor,
        )

        result = step.call

        assert_equal ["step1", "step2"], workflow_executor.executed_steps
        assert_equal({ condition_result: true, branch_executed: "then" }, result)
      end

      test "executes else branch for simple false condition" do
        workflow = Object.new
        workflow.define_singleton_method(:output) { {} }
        workflow.define_singleton_method(:model) { nil }

        # Mock instance_eval to return false
        workflow.define_singleton_method(:instance_eval) do |expr|
          !(expr == "false")
        end

        workflow_executor = Object.new
        workflow_executor.define_singleton_method(:execute_steps) { |steps| @executed_steps = steps }
        workflow_executor.define_singleton_method(:executed_steps) { @executed_steps }

        config = {
          "if" => "{{false}}",
          "then" => ["step1"],
          "else" => ["step2", "step3"],
        }

        step = ConditionalStep.new(
          workflow,
          config: config,
          name: "test_conditional",
          context_path: "/test/path",
          workflow_executor: workflow_executor,
        )

        result = step.call

        assert_equal ["step2", "step3"], workflow_executor.executed_steps
        assert_equal({ condition_result: false, branch_executed: "else" }, result)
      end

      test "unless inverts the condition" do
        workflow = Object.new
        workflow.define_singleton_method(:output) { {} }
        workflow.define_singleton_method(:model) { nil }

        # Mock instance_eval to return false
        workflow.define_singleton_method(:instance_eval) do |expr|
          !(expr == "false")
        end

        workflow_executor = Object.new
        workflow_executor.define_singleton_method(:execute_steps) { |steps| @executed_steps = steps }
        workflow_executor.define_singleton_method(:executed_steps) { @executed_steps }

        config = {
          "unless" => "{{false}}",
          "then" => ["step1", "step2"],
        }

        step = ConditionalStep.new(
          workflow,
          config: config,
          name: "test_conditional",
          context_path: "/test/path",
          workflow_executor: workflow_executor,
        )

        result = step.call

        assert_equal ["step1", "step2"], workflow_executor.executed_steps
        assert_equal({ condition_result: true, branch_executed: "then" }, result)
      end

      test "handles missing else branch" do
        workflow = Object.new
        workflow.define_singleton_method(:output) { {} }
        workflow.define_singleton_method(:model) { nil }

        # Mock instance_eval to return false
        workflow.define_singleton_method(:instance_eval) do |expr|
          !(expr == "false")
        end

        workflow_executor = Object.new
        workflow_executor.define_singleton_method(:execute_steps) { |steps| @executed_steps = steps }
        workflow_executor.define_singleton_method(:executed_steps) { @executed_steps }

        config = {
          "if" => "{{false}}",
          "then" => ["step1"],
        }

        step = ConditionalStep.new(
          workflow,
          config: config,
          name: "test_conditional",
          context_path: "/test/path",
          workflow_executor: workflow_executor,
        )

        result = step.call

        assert_nil workflow_executor.executed_steps
        assert_equal({ condition_result: false, branch_executed: "else" }, result)
      end
    end
  end
end
