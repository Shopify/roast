# frozen_string_literal: true

module Roast
  module Matchers
    class RateLimitMatcher < BaseMatcher
      def matches?(error)
        # Check for common rate limit indicators
        if error.respond_to?(:response) && error.response
          return true if error.response.status == 429
          
          # Check headers for rate limit indicators
          headers = error.response.headers
          return true if headers["x-ratelimit-remaining"] == "0"
          return true if headers["retry-after"]
        end
        
        # Check error message for rate limit keywords
        message = error.message.downcase
        rate_limit_keywords = ["rate limit", "too many requests", "quota exceeded"]
        rate_limit_keywords.any? { |keyword| message.include?(keyword) }
      end
    end
  end
end