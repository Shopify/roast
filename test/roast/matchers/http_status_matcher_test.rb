# frozen_string_literal: true

require "test_helper"

module Roast
  module Matchers
    class HttpStatusMatcherTest < ActiveSupport::TestCase
      test "matches default retryable statuses" do
        matcher = HttpStatusMatcher.new
        
        [408, 429, 500, 502, 503, 504].each do |status|
          error = create_http_error(status)
          assert matcher.matches?(error), "Should match status #{status}"
        end
      end

      test "does not match non-retryable statuses" do
        matcher = HttpStatusMatcher.new
        
        [400, 401, 403, 404, 422].each do |status|
          error = create_http_error(status)
          refute matcher.matches?(error), "Should not match status #{status}"
        end
      end

      test "matches custom statuses" do
        matcher = HttpStatusMatcher.new([400, 422])
        
        assert matcher.matches?(create_http_error(400))
        assert matcher.matches?(create_http_error(422))
        refute matcher.matches?(create_http_error(500))
      end

      test "returns false for non-http errors" do
        matcher = HttpStatusMatcher.new
        
        refute matcher.matches?(StandardError.new)
        refute matcher.matches?(ArgumentError.new)
      end

      test "returns false for http errors without response" do
        matcher = HttpStatusMatcher.new
        error = stub(response: nil)
        
        refute matcher.matches?(error)
      end

      private

      def create_http_error(status)
        response = stub(status: status)
        error = StandardError.new
        error.stubs(:response).returns(response)
        error
      end
    end
  end
end