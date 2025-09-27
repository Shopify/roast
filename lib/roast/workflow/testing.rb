# frozen_string_literal: true

module Roast
  module Workflow
    # Main module for step unit testing framework
    module Testing
      DEFAULT_BENCHMARK_ITERATIONS = 10
      class << self
        # Enable testing mode globally
        def enable!
          @enabled = true
          StepCoverage.start_tracking
        end

        # Disable testing mode
        def disable!
          @enabled = false
          StepCoverage.stop_tracking
        end

        # Check if testing mode is enabled
        def enabled?
          @enabled || false
        end

        # Reset all testing data
        def reset!
          StepCoverage.reset
          @enabled = false
        end

        # Generate a comprehensive test report
        def generate_report
          report = []
          report << "=== Roast Step Testing Report ==="
          report << "Generated at: #{Time.now}"
          report << ""

          # Add coverage report
          report << StepCoverage.generate_report
          report << ""

          # Add summary
          report << "=== Overall Summary ==="
          report << "Testing enabled: #{enabled?}"
          report << "Coverage percentage: #{StepCoverage.coverage_percentage}%"

          uncovered = StepCoverage.uncovered_branches
          if uncovered.any?
            report << ""
            report << "Uncovered branches:"
            uncovered.each { |branch| report << "  - #{branch}" }
          end

          report.join("\n")
        end

        # Export test results to JSON
        def export_results(filename)
          data = {
            timestamp: Time.now.iso8601,
            testing_enabled: enabled?,
            coverage: JSON.parse(StepCoverage.to_json),
          }

          File.write(filename, JSON.pretty_generate(data))
        end
      end

      class << self
        # Convenience method for creating a test harness
        def harness_for(step_class, options = {})
          StepTestHarness.new(step_class, options)
        end

        # Run a step in isolation with monitoring
        def run_isolated(step_class, config = {}, &block)
          harness = harness_for(step_class)
          monitor = PerformanceMonitor.new

          # Configure the step if block given
          yield harness if block_given?

          # Apply configuration
          harness.configure(config) if config.any?

          # Execute with monitoring
          monitor.start_monitoring
          result = harness.execute
          monitor.complete_monitoring(result.result)

          # Return result with performance data
          {
            result: result,
            performance: monitor.metrics,
            report: monitor.generate_report,
          }
        end

        # Benchmark a step with multiple configurations
        def benchmark_step(step_class, configurations = [{}], iterations = DEFAULT_BENCHMARK_ITERATIONS)
          results = []

          configurations.each_with_index do |config, config_index|
            monitor = PerformanceMonitor.new

            iterations.times do
              harness = harness_for(step_class)
              harness.configure(config) if config.any?

              monitor.start_monitoring
              result = harness.execute
              monitor.complete_monitoring(result.result)
            end

            results << {
              configuration: config,
              configuration_index: config_index,
              iterations: iterations,
              performance_report: monitor.generate_report,
              trends: monitor.performance_trends,
            }
          end

          results
        end

        # Validate a step against a specification
        def validate_step(step_class, specification)
          errors = []
          warnings = []

          # Check if step class exists and has required methods
          unless step_class.respond_to?(:new)
            errors << "Step class must be instantiable"
          end

          # Check required methods
          step_instance = begin
            step_class.new(MockWorkflow.new)
          rescue
            nil
          end
          if step_instance
            [:call, :name, :workflow].each do |method|
              unless step_instance.respond_to?(method)
                errors << "Step must respond to ##{method}"
              end
            end
          else
            errors << "Could not instantiate step for validation"
          end

          # Validate specification requirements
          if specification[:required_tools]
            # This would need actual execution to validate
            warnings << "Tool requirements cannot be validated statically"
          end

          if specification[:output_format]
            # This would need actual execution to validate
            warnings << "Output format cannot be validated statically"
          end

          {
            valid: errors.empty?,
            errors: errors,
            warnings: warnings,
          }
        end
      end
    end
  end
end
