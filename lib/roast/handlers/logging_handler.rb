# frozen_string_literal: true

module Roast
  module Handlers
    class LoggingHandler < BaseHandler
      attr_reader :logger

      def initialize(logger: nil)
        @logger = logger || default_logger
      end

      private

      def default_logger
        # Use Rails logger if available, otherwise create a basic logger
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger
        else
          Logger.new($stdout).tap do |log|
            log.level = Logger::INFO
          end
        end
      end

      def before_attempt(attempt)
        logger.info("Starting attempt #{attempt}")
      end

      def on_retry(error, attempt)
        logger.warn("Retrying after attempt #{attempt} due to #{error.class.name}: #{error.message}")
      end

      def on_success(attempt)
        if attempt > 1
          logger.info("Succeeded after #{attempt} attempts")
        end
      end

      def on_failure(error, attempt)
        logger.error("Failed after #{attempt} attempts with #{error.class.name}: #{error.message}")
      end
    end
  end
end