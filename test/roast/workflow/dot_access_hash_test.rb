# frozen_string_literal: true

require "test_helper"
require "roast/workflow/dot_access_hash"

module Roast
  module Workflow
    class DotAccessHashTest < ActiveSupport::TestCase
      def setup
        @hash = {
          simple_value: "test",
          nested: {
            level1: {
              level2: "deep value",
            },
          },
          boolean_true: true,
          boolean_false: false,
          nil_value: nil,
          number: 42,
        }
        @dot_access = DotAccessHash.new(@hash)
      end

      test "accesses simple values via dot notation" do
        assert_equal "test", @dot_access.simple_value
        assert_equal 42, @dot_access.number
      end

      test "accesses nested values via dot notation" do
        assert_equal "deep value", @dot_access.nested.level1.level2
      end

      test "returns nil for missing keys" do
        assert_nil @dot_access.missing_key
      end

      test "handles boolean predicate methods" do
        assert_equal true, @dot_access.boolean_true?
        assert_equal false, @dot_access.boolean_false?
        assert_equal false, @dot_access.nil_value?
        assert_equal true, @dot_access.number?
        # Missing keys should return false for predicate methods
        assert_equal false, @dot_access.missing_key?
      end

      test "responds to predicate methods correctly" do
        assert @dot_access.respond_to?(:boolean_true?)
        assert @dot_access.respond_to?(:simple_value?)
        assert @dot_access.respond_to?(:missing_key?) # Now returns true for all predicate methods
      end

      test "maintains backward compatibility with hash access" do
        assert_equal "test", @dot_access[:simple_value]
        assert_equal "deep value", @dot_access[:nested][:level1][:level2]
      end

      test "supports both string and symbol keys" do
        hash_with_string_keys = {
          "string_key" => "value",
          symbol_key: "another value",
        }
        dot_access = DotAccessHash.new(hash_with_string_keys)

        assert_equal "value", dot_access.string_key
        assert_equal "value", dot_access[:string_key]
        assert_equal "value", dot_access["string_key"]

        assert_equal "another value", dot_access.symbol_key
        assert_equal "another value", dot_access[:symbol_key]
      end

      test "handles setter methods" do
        @dot_access.new_value = "added"
        assert_equal "added", @dot_access.new_value

        @dot_access.nested.new_nested = "nested added"
        assert_equal "nested added", @dot_access.nested.new_nested
      end

      test "converts back to hash" do
        assert_equal @hash, @dot_access.to_h
      end

      test "handles empty hash" do
        empty_access = DotAccessHash.new({})
        assert_nil empty_access.any_key
        assert_equal false, empty_access.any_key?
      end

      test "handles nil hash" do
        nil_access = DotAccessHash.new(nil)
        assert_nil nil_access.any_key
        assert_equal false, nil_access.any_key?
      end

      test "raises NoMethodError for bang methods" do
        # Bang methods (ending with !) should still raise NoMethodError
        assert_raises(NoMethodError) do
          @dot_access.missing_key!
        end
      end

      test "responds_to? works correctly" do
        assert @dot_access.respond_to?(:simple_value)
        assert @dot_access.respond_to?(:nested)
        assert @dot_access.respond_to?(:missing_key) # Now returns true for all getter methods
        assert @dot_access.respond_to?(:new_value=)
      end
    end
  end
end
