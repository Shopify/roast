# frozen_string_literal: true

module Roast
  module Matchers
    class HttpStatusMatcher < BaseMatcher
      RETRYABLE_STATUSES = [408, 429, 500, 502, 503, 504].freeze

      attr_reader :statuses

      def initialize(statuses = RETRYABLE_STATUSES)
        @statuses = Array(statuses)
      end

      def matches?(error)
        return false unless error.respond_to?(:response)
        
        response = error.response
        return false unless response && response.respond_to?(:status)
        
        statuses.include?(response.status)
      end
    end
  end
end