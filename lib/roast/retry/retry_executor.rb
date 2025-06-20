# frozen_string_literal: true

module Roast
  module Retry
    class RetryExecutor
      def initialize(logger: Roast::Helpers::Logger)
        @logger = logger
      end

      def execute(strategy, &block)
        attempt = 0

        loop do
          attempt += 1

          begin
            return yield
          rescue StandardError => error
            if strategy.should_retry?(error, attempt)
              delay = strategy.calculate_delay(attempt)
              log_retry(attempt, error, delay)
              sleep(delay)
            else
              raise
            end
          end
        end
      end

      private

      def log_retry(attempt, error, delay)
        @logger.info("Retry attempt #{attempt} after #{error.class}: #{error.message}")
        @logger.info("Waiting #{delay.round(2)} seconds before retry")

        ActiveSupport::Notifications.instrument("roast.retry.attempt", {
          attempt: attempt,
          error: error.class.name,
          message: error.message,
          delay: delay,
        })
      end
    end
  end
end
