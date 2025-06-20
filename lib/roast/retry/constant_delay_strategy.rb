# frozen_string_literal: true

module Roast
  module Retry
    class ConstantDelayStrategy < RetryStrategy
      def calculate_delay(_attempt)
        base_delay
      end
    end
  end
end
