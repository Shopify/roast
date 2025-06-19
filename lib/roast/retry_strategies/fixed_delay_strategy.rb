# frozen_string_literal: true

module Roast
  module RetryStrategies
    class FixedDelayStrategy < BaseStrategy
      def calculate(attempt, base_delay:, max_delay:)
        base_delay
      end
    end
  end
end