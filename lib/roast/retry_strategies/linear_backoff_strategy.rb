# frozen_string_literal: true

module Roast
  module RetryStrategies
    class LinearBackoffStrategy < BaseStrategy
      def calculate(attempt, base_delay:, max_delay:)
        delay = base_delay * attempt
        [delay, max_delay].min
      end
    end
  end
end
