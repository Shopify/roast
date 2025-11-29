# typed: true
# frozen_string_literal: true

module Roast
  # Standardized logging interface for Roast
  # Delegates to Roast::Helpers::Logger for actual logging
  class Log
    class << self
      # Log an info message (equivalent to puts for user-facing output)
      # @param message [String] The message to log
      def info(message)
        Roast::Helpers::Logger.info(message)
      end

      # Log a debug message
      # @param message [String] The message to log
      def debug(message)
        Roast::Helpers::Logger.debug(message)
      end

      # Log a warning message
      # @param message [String] The message to log
      def warn(message)
        Roast::Helpers::Logger.warn(message)
      end

      # Log an error message
      # @param message [String] The message to log
      def error(message)
        Roast::Helpers::Logger.error(message)
      end

      # Log a fatal error message
      # @param message [String] The message to log
      def fatal(message)
        Roast::Helpers::Logger.fatal(message)
      end
    end
  end
end
