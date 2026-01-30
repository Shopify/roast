# typed: true
# frozen_string_literal: true

module Roast
  # Central logging interface for Roast.
  #
  # Provides a simple, testable logging API that wraps the standard library Logger.
  # Outputs to $stderr by default.
  #
  # @example Basic usage
  #   Roast::Log.info("Processing file...")
  #   Roast::Log.debug("Detailed info here")
  #   Roast::Log.warn("Something unexpected")
  #   Roast::Log.error("Something failed")
  #
  # @example Custom logger
  #   Roast::Log.logger = Rails.logger
  #
  module Log
    LOG_LEVELS = {
      "DEBUG" => ::Logger::DEBUG,
      "INFO" => ::Logger::INFO,
      "WARN" => ::Logger::WARN,
      "ERROR" => ::Logger::ERROR,
      "FATAL" => ::Logger::FATAL,
    }.freeze

    class << self
      attr_writer :logger

      def debug(message)
        logger.debug(message)
      end

      def info(message)
        logger.info(message)
      end

      def warn(message)
        logger.warn(message)
      end

      def error(message)
        logger.error(message)
      end

      def fatal(message)
        logger.fatal(message)
      end

      def logger
        @logger ||= create_logger
      end

      def reset!
        @logger = nil
      end

      private

      def create_logger
        ::Logger.new($stderr, progname: "roast").tap do |l|
          l.level = LOG_LEVELS.fetch(log_level)
        end
      end

      def log_level
        level_str = (ENV["ROAST_LOG_LEVEL"] || "INFO").upcase
        unless LOG_LEVELS.key?(level_str)
          raise ArgumentError, "Invalid log level: #{level_str}. Valid levels are: #{LOG_LEVELS.keys.join(", ")}"
        end

        level_str
      end
    end
  end
end
