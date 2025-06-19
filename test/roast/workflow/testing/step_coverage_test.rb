# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"

module Roast
  module Workflow
    module Testing
      class StepCoverageTest < ActiveSupport::TestCase
        class TestStep < BaseStep
          def call
            if workflow.verbose
              "verbose output"
            else
              "normal output"
            end
          end
        end

        class AnotherTestStep < BaseStep
          def call
            "another step output"
          end
        end

        def setup
          StepCoverage.reset
          StepCoverage.start_tracking
        end

        def teardown
          StepCoverage.stop_tracking
          StepCoverage.reset
        end

        test "tracks step executions" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_step_execution(AnotherTestStep)

          report = StepCoverage.generate_report

          assert_match(/Total Steps Tested: 2/, report)
          assert_match(/StepCoverageTest::TestStep/, report)
          assert_match(/Executions: 2/, report)
          assert_match(/StepCoverageTest::AnotherTestStep/, report)
          assert_match(/Executions: 1/, report)
        end

        test "tracks method calls" do
          StepCoverage.record_step_execution(TestStep, :call)
          StepCoverage.record_step_execution(TestStep, :initialize)

          report = StepCoverage.generate_report

          assert_match(/Methods called:/, report)
          assert_match(/call: 1 times/, report)
          assert_match(/initialize: 1 times/, report)
        end

        test "tracks branch coverage" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_branch_taken(TestStep, "verbose_check", true)
          StepCoverage.record_branch_taken(TestStep, "verbose_check", true)
          StepCoverage.record_branch_taken(TestStep, "verbose_check", false)

          report = StepCoverage.generate_report

          assert_match(/Branch coverage:/, report)
          assert_match(/verbose_check: 100.0%/, report)
          assert_match(/true: 2, false: 1/, report)
        end

        test "tracks prompt usage" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_prompt_used(TestStep, "prompt.md")
          StepCoverage.record_prompt_used(TestStep, "prompt.md")
          StepCoverage.record_prompt_used(TestStep, "alternate.md")

          report = StepCoverage.generate_report

          assert_match(/Prompts used:/, report)
          assert_match(/prompt.md: 2 times/, report)
          assert_match(/alternate.md: 1 times/, report)
        end

        test "tracks tool usage" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_tool_usage(TestStep, "read_file")
          StepCoverage.record_tool_usage(TestStep, "grep")
          StepCoverage.record_tool_usage(TestStep, "read_file") # Duplicate should be deduped

          report = StepCoverage.generate_report

          assert_match(/Tools used: (read_file, grep|grep, read_file)/, report)
        end

        test "tracks model usage" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_model_usage(TestStep, "gpt-4")
          StepCoverage.record_model_usage(TestStep, "gpt-3.5")

          report = StepCoverage.generate_report

          assert_match(/Models used: (gpt-4, gpt-3.5|gpt-3.5, gpt-4)/, report)
        end

        test "tracks execution paths" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_execution_path(TestStep, "path1")
          StepCoverage.record_execution_path(TestStep, "path2")
          StepCoverage.record_execution_path(TestStep, "path1") # Duplicate

          report = StepCoverage.generate_report

          assert_match(/Unique execution paths: 2/, report)
        end

        test "calculates coverage percentage" do
          # No data
          assert_equal 0.0, StepCoverage.coverage_percentage

          # Step with no branches
          StepCoverage.record_step_execution(TestStep)
          assert_equal 100.0, StepCoverage.coverage_percentage

          # Add branch coverage
          StepCoverage.record_branch_taken(TestStep, "check", true)
          # We have 1 step + 2 possible branch states (true/false) = 3 total
          # We've covered the step + 1 branch state = 2 covered
          # 2/3 = 66.7%
          assert_in_delta 66.7, StepCoverage.coverage_percentage, 0.1

          # Cover the false branch
          StepCoverage.record_branch_taken(TestStep, "check", false)
          assert_equal 100.0, StepCoverage.coverage_percentage
        end

        test "identifies uncovered branches" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_branch_taken(TestStep, "check1", true)
          StepCoverage.record_branch_taken(TestStep, "check2", false)

          uncovered = StepCoverage.uncovered_branches

          assert_equal 2, uncovered.size
          assert_includes uncovered, "#{TestStep.name}#check1:false"
          assert_includes uncovered, "#{TestStep.name}#check2:true"
        end

        test "generates json output" do
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_tool_usage(TestStep, "grep")

          json_output = StepCoverage.to_json
          data = JSON.parse(json_output)

          assert data["coverage_data"]
          assert_equal 1, data["summary"]["total_steps"]
          assert_equal 1, data["summary"]["total_executions"]
          assert_equal 100.0, data["summary"]["coverage_percentage"]
        end

        test "respects tracking enabled state" do
          StepCoverage.stop_tracking

          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_tool_usage(TestStep, "grep")

          assert_equal "No coverage data collected", StepCoverage.generate_report
        end

        test "generates comprehensive summary" do
          # Record varied data
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_step_execution(TestStep)
          StepCoverage.record_step_execution(AnotherTestStep)
          StepCoverage.record_tool_usage(TestStep, "read_file")
          StepCoverage.record_tool_usage(TestStep, "grep")
          StepCoverage.record_tool_usage(AnotherTestStep, "write_file")
          StepCoverage.record_model_usage(TestStep, "gpt-4")
          StepCoverage.record_model_usage(AnotherTestStep, "gpt-4")
          StepCoverage.record_branch_taken(TestStep, "check", true)
          StepCoverage.record_branch_taken(TestStep, "check", false)

          report = StepCoverage.generate_report

          # Check summary section
          assert_match(/=== Summary ===/, report)
          assert_match(/Total Step Executions: 3/, report)
          assert_match(/Unique Tools Used: 3/, report)
          assert_match(/Unique Models Used: 1/, report)
          assert_match(/Overall Branch Coverage: 100.0%/, report)
        end
      end

      class CoverageTrackingTest < ActiveSupport::TestCase
        class TrackedStep < BaseStep
          def initialize(workflow, **kwargs)
            super
            @model = "gpt-4"
          end

          def call
            "tracked result"
          end

          # Include after defining call method
          include CoverageTracking
        end

        def setup
          StepCoverage.reset
          StepCoverage.start_tracking
        end

        def teardown
          StepCoverage.stop_tracking
          StepCoverage.reset
        end

        test "automatically tracks step execution" do
          workflow = MockWorkflow.new
          step = TrackedStep.new(workflow)

          # The module should have been included and overridden the call method
          assert step.respond_to?(:call_without_coverage), "Module not properly included"

          result = step.call

          assert_equal "tracked result", result

          report = StepCoverage.generate_report
          assert_match(/CoverageTrackingTest::TrackedStep/, report)
          assert_match(/Executions: 1/, report)
          assert_match(/Models used: gpt-4/, report)
        end
      end
    end
  end
end
