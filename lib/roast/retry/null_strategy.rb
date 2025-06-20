# frozen_string_literal: true

module Roast
  module Retry
    class NullStrategy < RetryStrategy
      def should_retry?(_error, _attempt)
        false
      end

      def calculate_delay(_attempt)
        0
      end
    end
  end
end
