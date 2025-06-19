# frozen_string_literal: true

require "test_helper"

module Roast
  module Matchers
    class ErrorTypeMatcherTest < ActiveSupport::TestCase
      test "matches single error type" do
        matcher = ErrorTypeMatcher.new(ArgumentError)
        
        assert matcher.matches?(ArgumentError.new)
        refute matcher.matches?(StandardError.new)
        refute matcher.matches?(RuntimeError.new)
      end

      test "matches multiple error types" do
        matcher = ErrorTypeMatcher.new([ArgumentError, RuntimeError])
        
        assert matcher.matches?(ArgumentError.new)
        assert matcher.matches?(RuntimeError.new)
        refute matcher.matches?(StandardError.new)
      end

      test "matches subclasses" do
        matcher = ErrorTypeMatcher.new(StandardError)
        
        assert matcher.matches?(StandardError.new)
        assert matcher.matches?(RuntimeError.new)
        assert matcher.matches?(ArgumentError.new)
        refute matcher.matches?(Exception.new)
      end
    end
  end
end