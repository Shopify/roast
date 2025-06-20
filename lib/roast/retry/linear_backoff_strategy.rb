# frozen_string_literal: true

module Roast
  module Retry
    class LinearBackoffStrategy < RetryStrategy
      attr_reader :increment

      def initialize(config = {})
        super
        @increment = config.fetch("increment", base_delay)
      end

      def calculate_delay(attempt)
        delay = base_delay + (increment * (attempt - 1))
        [delay, max_delay].min
      end
    end
  end
end
