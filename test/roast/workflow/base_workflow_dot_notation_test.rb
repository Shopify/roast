# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseWorkflowDotNotationTest < ActiveSupport::TestCase
      def setup
        @workflow = BaseWorkflow.new
      end

      test "allows direct access to output values via method_missing" do
        @workflow.output[:step_result] = "success"

        assert_equal "success", @workflow.step_result
      end

      test "allows direct access to nested output values" do
        @workflow.output[:analyze] = { result: "pass", score: 95 }

        assert_equal "pass", @workflow.analyze.result
        assert_equal 95, @workflow.analyze.score
      end

      test "supports predicate methods on workflow directly" do
        @workflow.output[:completed] = true
        @workflow.output[:failed] = false
        @workflow.output[:empty] = nil

        assert_equal true, @workflow.completed?
        assert_equal false, @workflow.failed?
        assert_equal false, @workflow.empty?
      end

      test "responds_to? works correctly for output keys" do
        @workflow.output[:existing_key] = "value"

        assert @workflow.respond_to?(:existing_key)
        assert @workflow.respond_to?(:existing_key?)
        assert @workflow.respond_to?(:missing_key) # Now returns true for all methods
      end

      test "returns nil for undefined output keys" do
        # Since output now returns nil for missing keys, workflow should too
        assert_nil @workflow.undefined_key
      end

      test "raises NoMethodError for methods with arguments" do
        # Methods with arguments that don't exist should still raise
        assert_raises(NoMethodError) do
          @workflow.undefined_method("arg")
        end
      end

      test "maintains access to actual workflow methods" do
        assert_respond_to @workflow, :name
        assert_respond_to @workflow, :configuration
        assert_respond_to @workflow, :output
      end

      test "supports the example from the issue" do
        # Set up data matching the issue example
        @workflow.output[:update_fix_count] = { fixes_applied: 3 }
        @workflow.output[:select_next_issue] = { no_issues_left: false }

        # Test the simplified syntax works
        assert_equal 3, @workflow.update_fix_count.fixes_applied
        assert_equal false, @workflow.select_next_issue.no_issues_left

        # Test with predicate method
        assert_equal false, @workflow.select_next_issue.no_issues_left?
      end

      test "evaluates conditional expressions correctly" do
        @workflow.output[:update_fix_count] = { fixes_applied: 6 }
        @workflow.output[:select_next_issue] = { no_issues_left: true }

        # This simulates how the condition would be evaluated
        condition = @workflow.instance_eval do
          update_fix_count.fixes_applied >= 5 || select_next_issue.no_issues_left?
        end

        assert_equal true, condition
      end
    end
  end
end
