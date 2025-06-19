# frozen_string_literal: true

module Roast
  module Matchers
    class ErrorMessageMatcher < BaseMatcher
      attr_reader :pattern

      def initialize(pattern)
        unless pattern.is_a?(String) || pattern.is_a?(Regexp)
          raise ArgumentError, "Pattern must be a String or Regexp"
        end
        @pattern = pattern
      end

      def matches?(error)
        case pattern
        when Regexp
          pattern.match?(error.message)
        when String
          error.message.include?(pattern)
        else
          raise ArgumentError, "Pattern must be a String or Regexp"
        end
      end
    end
  end
end