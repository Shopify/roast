# frozen_string_literal: true

module Roast
  module Metrics
    class RetryMetrics
      attr_reader :attempts, :retries, :successes, :failures, :durations

      def initialize
        @attempts = 0
        @retries = 0
        @successes = 0
        @failures = 0
        @durations = []
      end

      def record_attempt(attempt)
        @attempts += 1
      end

      def record_retry(attempt)
        @retries += 1
      end

      def record_success(attempt, duration)
        @successes += 1
        @durations << duration
      end

      def record_failure(attempt, duration)
        @failures += 1
        @durations << duration
      end

      def average_duration
        return 0 if durations.empty?
        durations.sum / durations.size
      end

      def success_rate
        total = successes + failures
        return 0 if total == 0
        (successes.to_f / total) * 100
      end

      def to_h
        {
          attempts: attempts,
          retries: retries,
          successes: successes,
          failures: failures,
          average_duration: average_duration,
          success_rate: success_rate
        }
      end
    end
  end
end