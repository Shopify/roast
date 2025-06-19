# frozen_string_literal: true

module Roast
  module RetryStrategies
    class BaseStrategy
      def calculate(attempt, base_delay:, max_delay:)
        raise NotImplementedError, "Subclasses must implement #calculate"
      end
    end
  end
end
