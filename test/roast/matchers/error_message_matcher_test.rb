# frozen_string_literal: true

require "test_helper"

module Roast
  module Matchers
    class ErrorMessageMatcherTest < ActiveSupport::TestCase
      test "matches string pattern" do
        matcher = ErrorMessageMatcher.new("timeout")

        assert matcher.matches?(StandardError.new("Connection timeout"))
        assert matcher.matches?(StandardError.new("Request timeout occurred"))
        refute matcher.matches?(StandardError.new("Connection refused"))
      end

      test "matches regex pattern" do
        matcher = ErrorMessageMatcher.new(/timeout|rate limit/i)

        assert matcher.matches?(StandardError.new("Connection timeout"))
        assert matcher.matches?(StandardError.new("Rate limit exceeded"))
        assert matcher.matches?(StandardError.new("TIMEOUT ERROR"))
        refute matcher.matches?(StandardError.new("Connection refused"))
      end

      test "raises error for invalid pattern type" do
        assert_raises(ArgumentError) do
          ErrorMessageMatcher.new(123)
        end
      end
    end
  end
end
