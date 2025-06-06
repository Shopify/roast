# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InterpolatorTest < ActiveSupport::TestCase
      def setup
        @context = Object.new
        @interpolator = Interpolator.new(@context)
      end

      def test_returns_text_without_interpolation_markers
        assert_equal("plain text", @interpolator.interpolate("plain text"))
      end

      def test_returns_non_string_values_unchanged
        assert_equal(123, @interpolator.interpolate(123))
        assert_nil(@interpolator.interpolate(nil))
        assert_equal([:a, :b], @interpolator.interpolate([:a, :b]))
      end

      def test_interpolates_simple_variable
        @context.instance_variable_set(:@file, "test.rb")
        @context.define_singleton_method(:file) { @file }

        result = @interpolator.interpolate("{{file}}")
        assert_equal("test.rb", result)
      end

      def test_interpolates_variable_with_surrounding_text
        @context.instance_variable_set(:@file, "test.rb")
        @context.define_singleton_method(:file) { @file }

        result = @interpolator.interpolate("Process {{file}} with rubocop")
        assert_equal("Process test.rb with rubocop", result)
      end

      def test_interpolates_multiple_variables
        @context.instance_variable_set(:@file, "test.rb")
        @context.instance_variable_set(:@line, 42)
        @context.define_singleton_method(:file) { @file }
        @context.define_singleton_method(:line) { @line }

        result = @interpolator.interpolate("{{file}}:{{line}}")
        assert_equal("test.rb:42", result)
      end

      def test_interpolates_complex_expressions
        @context.instance_variable_set(:@output, { "previous_step" => "result" })
        @context.define_singleton_method(:output) { @output }

        result = @interpolator.interpolate("Using {{output['previous_step']}}")
        assert_equal("Using result", result)
      end

      def test_preserves_expression_on_error
        result = @interpolator.interpolate("Process {{unknown_var}}")
        assert_equal("Process {{unknown_var}}", result)
      end

      def test_logs_error_for_failed_interpolation
        logger = mock("Logger")
        interpolator = Interpolator.new(@context, logger: logger)

        logger.expects(:error) do |msg|
          msg.include?("Error interpolating {{unknown}}:") &&
            msg.include?("undefined local variable or method") &&
            msg.include?("This variable is not defined in the workflow context.")
        end

        interpolator.interpolate("{{unknown}}")
      end

      def test_handles_nested_braces_correctly
        @context.instance_variable_set(:@data, { key: "value" })
        @context.define_singleton_method(:data) { @data }

        result = @interpolator.interpolate("{{data[:key]}}")
        assert_equal("value", result)
      end
    end
  end
end
