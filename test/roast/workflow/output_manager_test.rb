# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class OutputManagerTest < ActiveSupport::TestCase
      def setup
        @manager = OutputManager.new
      end

      def test_initializes_with_empty_output
        assert_instance_of(DotAccessHash, @manager.output)
        assert_empty(@manager.raw_output)
      end

      def test_initializes_with_empty_final_output
        assert_equal("", @manager.final_output)
      end

      def test_output_setter_converts_hash_to_indifferent_access
        regular_hash = { "key" => "value" }
        @manager.output = regular_hash

        assert_instance_of(ActiveSupport::HashWithIndifferentAccess, @manager.raw_output)
        assert_equal("value", @manager.output[:key])
        assert_equal("value", @manager.output["key"])
      end

      def test_output_setter_preserves_indifferent_access
        indifferent_hash = ActiveSupport::HashWithIndifferentAccess.new(key: "value")
        @manager.output = indifferent_hash

        assert_same(indifferent_hash, @manager.raw_output)
      end

      def test_output_supports_dot_notation_access
        @manager.output = {
          simple: "value",
          nested: {
            level1: {
              level2: "deep",
            },
          },
        }

        assert_equal("value", @manager.output.simple)
        assert_equal("deep", @manager.output.nested.level1.level2)
      end

      def test_output_supports_predicate_methods
        @manager.output = {
          truthy: true,
          falsy: false,
          nil_val: nil,
          present: "here",
        }

        assert_equal(true, @manager.output.truthy?)
        assert_equal(false, @manager.output.falsy?)
        assert_equal(false, @manager.output.nil_val?)
        assert_equal(true, @manager.output.present?)
      end

      def test_append_to_final_output
        @manager.append_to_final_output("First message")
        @manager.append_to_final_output("Second message")

        assert_equal("First message\n\nSecond message", @manager.final_output)
      end

      def test_final_output_returns_string_directly
        @manager.instance_variable_set(:@final_output, "Direct string")
        assert_equal("Direct string", @manager.final_output)
      end

      def test_final_output_returns_empty_string_for_nil
        @manager.instance_variable_set(:@final_output, nil)
        assert_equal("", @manager.final_output)
      end

      def test_final_output_converts_other_types_to_string
        @manager.instance_variable_set(:@final_output, 42)
        assert_equal("42", @manager.final_output)
      end

      def test_to_h_returns_state_snapshot
        @manager.output["key"] = "value"
        @manager.append_to_final_output("Message")

        snapshot = @manager.to_h
        assert_equal({ "key" => "value" }, snapshot[:output])
        assert_equal(["Message"], snapshot[:final_output])
      end

      def test_from_h_restores_state
        data = {
          output: { "restored" => "data" },
          final_output: ["Restored message"],
        }

        @manager.from_h(data)
        assert_equal("data", @manager.output["restored"])
        assert_equal("Restored message", @manager.final_output)
      end

      def test_from_h_handles_nil_gracefully
        @manager.from_h(nil)
        assert_empty(@manager.output)
        assert_equal("", @manager.final_output)
      end

      def test_from_h_handles_partial_data
        @manager.output["existing"] = "value"
        @manager.from_h({ final_output: "New output" })

        assert_equal("value", @manager.output["existing"])
        assert_equal("New output", @manager.final_output)
      end
    end
  end
end
