# frozen_string_literal: true

module Roast
  module Retry
    class RetryStrategy
      attr_reader :max_attempts, :base_delay, :max_delay

      def initialize(config = {})
        @max_attempts = config.fetch("max_attempts", 3)
        @base_delay = config.fetch("base_delay", 1.0)
        @max_delay = config.fetch("max_delay", 60.0)
      end

      def should_retry?(error, attempt)
        retryable_error?(error) && attempt <= max_attempts
      end

      def calculate_delay(attempt)
        raise NotImplementedError, "Subclasses must implement #calculate_delay"
      end

      private

      def retryable_error?(error)
        case error
        when Net::ReadTimeout, Net::OpenTimeout, Timeout::Error
          true
        when StandardError
          error.message.include?("rate limit") ||
            error.message.include?("temporarily unavailable") ||
            error.message.include?("server error")
        else
          false
        end
      end
    end
  end
end
