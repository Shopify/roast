# frozen_string_literal: true

module Roast
  module RetryStrategies
    class ExponentialBackoffStrategy < BaseStrategy
      def calculate(attempt, base_delay:, max_delay:)
        delay = base_delay * (2**(attempt - 1))
        [delay, max_delay].min
      end
    end
  end
end
