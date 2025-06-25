# frozen_string_literal: true

require "test_helper"

module Roast
  module Matchers
    class RateLimitMatcherTest < ActiveSupport::TestCase
      setup do
        @matcher = RateLimitMatcher.new
      end

      test "matches 429 status code" do
        error = create_http_error(429, {})
        assert @matcher.matches?(error)
      end

      test "matches x-ratelimit-remaining header with 0" do
        error = create_http_error(403, { "x-ratelimit-remaining" => "0" })
        assert @matcher.matches?(error)
      end

      test "matches retry-after header" do
        error = create_http_error(503, { "retry-after" => "60" })
        assert @matcher.matches?(error)
      end

      test "matches rate limit keywords in message" do
        assert @matcher.matches?(StandardError.new("Rate limit exceeded"))
        assert @matcher.matches?(StandardError.new("Too many requests"))
        assert @matcher.matches?(StandardError.new("Quota exceeded for API"))
        assert @matcher.matches?(StandardError.new("API RATE LIMIT HIT"))
      end

      test "does not match unrelated errors" do
        refute @matcher.matches?(StandardError.new("Connection refused"))
        refute @matcher.matches?(create_http_error(500, {}))
      end

      test "handles errors without response gracefully" do
        refute @matcher.matches?(StandardError.new("Connection error"))
      end

      private

      def create_http_error(status, headers)
        response = stub(status: status, headers: headers)
        error = StandardError.new
        error.stubs(:response).returns(response)
        error
      end
    end
  end
end
