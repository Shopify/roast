# frozen_string_literal: true

module Roast
  module Handlers
    class ExponentialBackoffHandler < BaseHandler
      attr_reader :logger, :base_delay, :max_delay

      def initialize(logger: nil, base_delay: 1, max_delay: 60)
        super()
        @logger = logger || Roast::Helpers::Logger.instance
        @base_delay = base_delay
        @max_delay = max_delay
      end

      def on_retry(error, attempt)
        delay = calculate_delay(attempt)
        logger.info("Backing off for #{delay}s before retry attempt #{attempt + 1}")
      end

      private

      def calculate_delay(attempt)
        delay = base_delay * (2**(attempt - 1))
        [delay, max_delay].min
      end
    end
  end
end
