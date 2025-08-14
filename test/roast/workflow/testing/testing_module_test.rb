# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"

module Roast
  module Workflow
    module Testing
      class TestingModuleTest < ActiveSupport::TestCase
        class SampleStep < BaseStep
          def call
            prompt("Sample prompt")
            chat_completion
          end
        end

        def setup
          Testing.reset!
        end

        def teardown
          Testing.reset!
        end

        test "enable and disable testing mode" do
          refute Testing.enabled?

          Testing.enable!
          assert Testing.enabled?

          Testing.disable!
          refute Testing.enabled?
        end

        test "reset clears all data" do
          Testing.enable!
          StepCoverage.record_step_execution(SampleStep)

          Testing.reset!

          refute Testing.enabled?
          assert_equal "No coverage data collected", StepCoverage.generate_report
        end

        test "generate comprehensive report" do
          Testing.enable!

          # Record some test data
          StepCoverage.record_step_execution(SampleStep)
          StepCoverage.record_tool_usage(SampleStep, "read_file")

          report = Testing.generate_report

          assert_match(/=== Roast Step Testing Report ===/, report)
          assert_match(/Generated at:/, report)
          assert_match(/Step Coverage Report/, report)
          assert_match(/Testing enabled: true/, report)
          assert_match(/Coverage percentage: 100.0%/, report)
        end

        test "export results to json" do
          Testing.enable!
          StepCoverage.record_step_execution(SampleStep)

          # Use a temporary file
          Dir.mktmpdir do |dir|
            filename = File.join(dir, "test_results.json")
            Testing.export_results(filename)

            assert File.exist?(filename)

            data = JSON.parse(File.read(filename))
            assert data["timestamp"]
            assert data["testing_enabled"]
            assert data["coverage"]
            assert_equal 1, data["coverage"]["summary"]["total_steps"]
          end
        end

        test "harness_for creates test harness" do
          harness = Testing.harness_for(SampleStep, model: "gpt-4")

          assert_kind_of StepTestHarness, harness
          assert_kind_of SampleStep, harness.step
        end

        test "run_isolated executes step with monitoring" do
          result = Testing.run_isolated(SampleStep) do |harness|
            harness.with_mock_response("Isolated response")
          end

          assert result[:result].success?
          assert_equal "Isolated response", result[:result].result
          assert result[:performance]
          assert_match(/Performance Report/, result[:report])
        end

        test "run_isolated with configuration" do
          result = Testing.run_isolated(SampleStep, { model: "gpt-4", json: true }) do |harness|
            harness.with_mock_response({ "key" => "value" })
          end

          assert_equal({ "key" => "value" }, result[:result].result)
        end

        test "benchmark_step runs multiple iterations" do
          configurations = [
            { model: "gpt-4" },
            { model: "gpt-3.5", json: true },
          ]

          results = Testing.benchmark_step(SampleStep, configurations, 3)

          assert_equal 2, results.size

          results.each_with_index do |result, index|
            assert_equal configurations[index], result[:configuration]
            assert_equal index, result[:configuration_index]
            assert_equal 3, result[:iterations]
            assert result[:performance_report]
            assert result[:trends]
          end
        end

        test "validate_step checks step requirements" do
          # Valid step
          validation = Testing.validate_step(SampleStep, {})

          assert validation[:valid]
          assert_empty validation[:errors]

          # Test with specifications that can't be validated statically
          validation = Testing.validate_step(SampleStep, {
            required_tools: ["read_file"],
            output_format: :string,
          })

          assert validation[:valid]
          assert_equal 2, validation[:warnings].size
        end

        test "validate_step detects invalid steps" do
          # Create an invalid step class
          invalid_step = Class.new do
            def initialize(workflow)
              # Missing required methods
            end
          end

          validation = Testing.validate_step(invalid_step, {})

          refute validation[:valid]
          assert validation[:errors].any? { |e| e.include?("must respond to") }
        end

        test "integration of all testing components" do
          Testing.enable!

          # Make sure we're tracking by recording executions manually
          StepCoverage.record_step_execution(SampleStep, :call)
          StepCoverage.record_step_execution(SampleStep, :call)

          # Run a step with harness
          harness1 = Testing.harness_for(SampleStep)
          harness1.with_mock_response("Response 1").execute

          # Generate final report
          report = Testing.generate_report

          assert_match(/SampleStep/, report)
          assert_match(/Total Step Executions: 2/, report)
        end
      end
    end
  end
end
