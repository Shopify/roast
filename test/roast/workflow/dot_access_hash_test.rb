# frozen_string_literal: true

require "test_helper"

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

      test "merge combines two DotAccessHash objects" do
        other_hash = {
          another_value: "test2",
          nested: {
            level1: {
              level3: "new deep value",
            },
          },
        }
        other_dot_access = DotAccessHash.new(other_hash)

        merged = @dot_access.merge(other_dot_access)

        # Original values are preserved
        assert_equal "test", merged.simple_value
        assert_equal 42, merged.number

        # New values are added
        assert_equal "test2", merged.another_value

        # Nested values are merged (not deep merged, just replaced)
        assert_equal "new deep value", merged.nested.level1.level3
        # NOTE: level2 is gone because the entire nested hash was replaced
        assert_nil merged.nested.level1.level2
      end

      test "merge works with regular hash" do
        other_hash = {
          another_value: "test2",
          simple_value: "overridden",
        }

        merged = @dot_access.merge(other_hash)

        # Original value is overridden
        assert_equal "overridden", merged.simple_value
        # New value is added
        assert_equal "test2", merged.another_value
        # Other values are preserved
        assert_equal 42, merged.number
      end

      test "values returns all values" do
        values = @dot_access.values
        assert_includes values, "test"
        assert_includes values, true
        assert_includes values, false
        assert_includes values, nil
        assert_includes values, 42
        assert_equal 6, values.size
      end

      test "key?, has_key?, and include? work correctly" do
        assert @dot_access.key?(:simple_value)
        assert @dot_access.key?("simple_value")
        assert @dot_access.include?(:simple_value)

        assert_not @dot_access.key?(:missing_key)
        assert_not @dot_access.key?("missing_key")
        assert_not @dot_access.include?(:missing_key)
      end

      test "fetch returns value when key exists" do
        assert_equal "test", @dot_access.fetch(:simple_value)
        assert_equal "test", @dot_access.fetch("simple_value")
      end

      test "fetch returns default when key missing" do
        assert_equal "default", @dot_access.fetch(:missing_key, "default")
        assert_nil @dot_access.fetch(:missing_key, nil)
      end

      test "fetch yields block when key missing" do
        result = @dot_access.fetch(:missing_key) { |key| "missing: #{key}" }
        assert_equal "missing: missing_key", result
      end

      test "fetch raises KeyError when no default and no block" do
        error = assert_raises(KeyError) do
          @dot_access.fetch(:missing_key)
        end
        assert_match(/key not found/, error.message)
      end

      test "dig navigates nested structures" do
        assert_equal "deep value", @dot_access.dig(:nested, :level1, :level2)
        assert_nil @dot_access.dig(:nested, :level1, :missing)
        assert_nil @dot_access.dig(:missing, :level1, :level2)
      end

      test "size and length return number of keys" do
        assert_equal 6, @dot_access.size
        assert_equal 6, @dot_access.length
      end

      test "map transforms key-value pairs" do
        result = @dot_access.map { |k, v| [k, v.class.name] }
        assert_includes result, [:simple_value, "String"]
        assert_includes result, [:number, "Integer"]
      end

      test "select filters hash" do
        selected = @dot_access.select { |_k, v| v.is_a?(String) }
        assert_equal "test", selected.simple_value
        assert_nil selected.number
      end

      test "reject filters out matching pairs" do
        rejected = @dot_access.reject { |_k, v| v.nil? }
        assert_equal "test", rejected.simple_value
        assert_nil rejected[:nil_value]
      end

      test "compact removes nil values" do
        compacted = @dot_access.compact
        assert_equal "test", compacted.simple_value
        assert_not compacted.key?(:nil_value)
      end

      test "slice extracts subset of keys" do
        sliced = @dot_access.slice(:simple_value, :number, :missing_key)
        assert_equal "test", sliced.simple_value
        assert_equal 42, sliced.number
        assert_not sliced.key?(:boolean_true)
      end

      test "except excludes specified keys" do
        excepted = @dot_access.except(:simple_value, :number)
        assert_not excepted.key?(:simple_value)
        assert_not excepted.key?(:number)
        assert excepted.key?(:boolean_true)
      end

      test "delete removes key and returns value" do
        copy = DotAccessHash.new(@hash.dup)
        assert_equal "test", copy.delete(:simple_value)
        assert_nil copy.simple_value
        assert_nil copy.delete(:missing_key)
      end

      test "clear empties the hash" do
        copy = DotAccessHash.new(@hash.dup)
        copy.clear
        assert copy.empty?
        assert_equal 0, copy.size
      end

      test "equality comparison works" do
        same_hash = DotAccessHash.new(@hash.dup)
        assert_equal @dot_access, same_hash
        assert_equal @dot_access, @hash
        assert_not_equal @dot_access, { different: "hash" }
        assert_not_equal @dot_access, "not a hash"
      end
    end
  end
end
