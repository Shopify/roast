# frozen_string_literal: true

module Roast
  module Workflow
    module Testing
      # Base test case class for testing workflow steps
      class StepTestCase < ActiveSupport::TestCase
        class << self
          attr_accessor :step_class

          # DSL method to specify which step class is being tested
          def test_step(klass)
            @step_class = klass
          end
        end

        # Setup method that creates harness for each test
        def setup
          super
          @harness = StepTestHarness.new(self.class.step_class || infer_step_class)
          @performance_monitor = PerformanceMonitor.new
          StepCoverage.start_tracking
        end

        def teardown
          super
          StepCoverage.stop_tracking
        end

        # Create a test harness for the step
        attr_reader :harness

        # Execute step with optional configuration
        def execute_step(config = {})
          @performance_monitor.start_monitoring

          # Apply configuration
          harness.configure(config) if config.any?

          # Execute the step
          result = harness.execute

          # Complete monitoring
          @performance_monitor.complete_monitoring(result.result)

          result
        end

        # Assert that step execution succeeds
        def assert_step_succeeds(config = {})
          result = execute_step(config)
          assert(result.success?, "Step execution failed: #{result.error&.message}")
          result
        end

        # Assert that step execution fails
        def assert_step_fails(config = {}, error_class = nil)
          result = execute_step(config)
          assert(result.failure?, "Expected step to fail but it succeeded")

          if error_class
            assert_kind_of(
              error_class,
              result.error,
              "Expected error of type #{error_class}, got #{result.error.class}",
            )
          end

          result
        end

        # Assert output format
        def assert_output_format(format, config = {})
          result = assert_step_succeeds(config)
          assert(
            StepValidators.validate_output_format(result.result, format),
            "Output format validation failed. Expected #{format}, got #{result.result.class}",
          )
        end

        # Assert required fields in output
        def assert_required_fields(fields, config = {})
          result = assert_step_succeeds(config)
          StepValidators.validate_required_fields(result.result, fields)
        end

        # Assert output matches schema
        def assert_output_schema(schema, config = {})
          result = assert_step_succeeds(config)
          StepValidators.validate_schema(result.result, schema)
        end

        # Assert transcript contains pattern
        def assert_transcript_contains(pattern, config = {})
          result = assert_step_succeeds(config)
          assert(
            StepValidators.validate_transcript_pattern(result.transcript, pattern),
            "Transcript does not contain expected pattern: #{pattern}",
          )
        end

        # Assert specific tools were used
        def assert_tools_used(tools, config = {})
          result = assert_step_succeeds(config)
          StepValidators.validate_tool_usage(result.transcript, tools)
        end

        # Assert performance thresholds
        def assert_performance(thresholds, config = {})
          assert_step_succeeds(config)
          assert(
            @performance_monitor.meets_threshold?(thresholds),
            "Performance thresholds not met: #{@performance_monitor.generate_report}",
          )
        end

        # Mock a response for the step
        def with_mock_response(response, options = {})
          harness.with_mock_response(response, options)
          self
        end

        # Mock multiple responses for the step
        def with_mock_responses(*responses)
          harness.with_mock_responses(*responses)
          self
        end

        # Set available tools for the step
        def with_tools(tools)
          harness.with_tools(tools)
          self
        end

        # Set initial workflow state
        def with_initial_state(state)
          harness.with_initial_output(state)
          self
        end

        # Set resource for the step
        def with_resource(resource)
          harness.with_resource(resource)
          self
        end

        # Add initial transcript entries
        def with_transcript(*entries)
          harness.with_initial_transcript(*entries)
          self
        end

        # Get coverage report
        def coverage_report
          StepCoverage.generate_report
        end

        # Get performance report
        def performance_report
          @performance_monitor.generate_report
        end

        protected

        def infer_step_class
          # Try to infer step class from test class name
          # e.g., MyStepTest -> MyStep
          test_class_name = self.class.name
          step_class_name = test_class_name.sub(/Test$/, "")

          begin
            Object.const_get(step_class_name)
          rescue NameError
            raise "Cannot infer step class. Use 'test_step' class method to specify it."
          end
        end
      end

      # Assertion helpers module
      module StepAssertions
        # Assert that a value matches the expected type or structure
        def assert_matches_structure(expected, actual, message = nil)
          case expected
          when Hash
            assert(actual.is_a?(Hash), message || "Expected Hash, got #{actual.class}")
            expected.each do |key, expected_value|
              assert(
                actual.key?(key.to_s) || actual.key?(key.to_sym),
                message || "Missing key: #{key}",
              )
              actual_value = actual[key.to_s] || actual[key.to_sym]
              assert_matches_structure(expected_value, actual_value, message)
            end
          when Array
            assert(actual.is_a?(Array), message || "Expected Array, got #{actual.class}")
            if expected.size == 1
              # Check all elements match the pattern
              actual.each do |item|
                assert_matches_structure(expected.first, item, message)
              end
            end
          when Class
            assert(
              actual.is_a?(expected),
              message || "Expected #{expected}, got #{actual.class}",
            )
          when Symbol
            case expected
            when :string
              assert(actual.is_a?(String), message || "Expected String, got #{actual.class}")
            when :integer
              assert(actual.is_a?(Integer), message || "Expected Integer, got #{actual.class}")
            when :float
              assert(
                actual.is_a?(Float) || actual.is_a?(Integer),
                message || "Expected Float, got #{actual.class}",
              )
            when :boolean
              assert(
                [true, false].include?(actual),
                message || "Expected boolean, got #{actual.class}",
              )
            end
          else
            assert_equal(expected, actual, message)
          end
        end

        # Assert step produces deterministic output
        def assert_deterministic_output(config = {}, iterations = 3)
          outputs = []

          iterations.times do
            result = execute_step(config)
            assert(result.success?, "Step execution failed")
            outputs << result.result
          end

          # Check all outputs are identical
          first_output = outputs.first
          outputs[1..].each_with_index do |output, index|
            assert_equal(
              first_output,
              output,
              "Non-deterministic output detected. Iteration #{index + 2} differs from first",
            )
          end
        end

        # Assert step handles edge cases properly
        def assert_handles_edge_case(edge_case_input, expected_behavior = :success)
          harness.with_mock_response(edge_case_input)

          case expected_behavior
          when :success
            assert_step_succeeds
          when :failure
            assert_step_fails
          when :graceful_degradation
            result = execute_step
            assert(result.success?, "Step should degrade gracefully")
            assert(result.result, "Step should produce some output even with edge case")
          else
            raise ArgumentError, "Unknown expected behavior: #{expected_behavior}"
          end
        end
      end

      # Include assertion helpers in test case
      StepTestCase.include(StepAssertions)
    end
  end
end
