# frozen_string_literal: true

module Roast
  module Metrics
    class NullMetrics
      def record_attempt(attempt)
        # No-op
      end

      def record_retry(attempt)
        # No-op
      end

      def record_success(attempt, duration)
        # No-op
      end

      def record_failure(attempt, duration)
        # No-op
      end
    end
  end
end
