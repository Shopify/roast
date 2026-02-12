# frozen_string_literal: true

require "test_helper"

class NilAssertionsTest < ActiveSupport::TestCase
  test "! returns self for non-nil objects" do
    str = "hello"
    result = str.!

    assert_equal str, result
    assert_same str, result
  end

  test "! returns self for numeric values" do
    num = 42
    result = num.!

    assert_equal num, result
  end

  test "! returns self for arrays" do
    arr = [1, 2, 3]
    result = arr.!

    assert_equal arr, result
    assert_same arr, result
  end

  test "! returns self for hashes" do
    hash = { key: "value" }
    result = hash.!

    assert_equal hash, result
    assert_same hash, result
  end

  test "! returns self for false" do
    result = false.!

    assert_equal false, result
  end

  test "! raises UnexpectedNilError for nil" do
    error = assert_raises(UnexpectedNilError) do
      nil.!
    end

    assert_equal "Unexpected nil value encountered.", error.message
  end

  test "UnexpectedNilError can be initialized with custom message" do
    error = UnexpectedNilError.new("Custom error message")

    assert_equal "Custom error message", error.message
  end

  test "UnexpectedNilError uses default message when initialized without arguments" do
    error = UnexpectedNilError.new

    assert_equal "Unexpected nil value encountered.", error.message
  end

  test "! can be chained with other methods on non-nil values" do
    result = "hello".!.upcase

    assert_equal "HELLO", result
  end

  test "! raises before chaining when value is nil" do
    assert_raises(UnexpectedNilError) do
      nil.!.upcase
    end
  end
end
