# frozen_string_literal: true

module Roast
  module Retry
    class ExponentialBackoffStrategy < RetryStrategy
      attr_reader :jitter, :multiplier

      def initialize(config = {})
        super
        @jitter = config.fetch("jitter", true)
        @multiplier = config.fetch("multiplier", 2.0)
      end

      def calculate_delay(attempt)
        delay = base_delay * (multiplier**(attempt - 1))
        delay = [delay, max_delay].min

        if jitter
          # Add random jitter up to 25% of the delay
          jitter_amount = delay * 0.25 * rand
          delay + jitter_amount
        else
          delay
        end
      end
    end
  end
end
