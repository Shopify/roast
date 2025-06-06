# frozen_string_literal: true

module Roast
  module Helpers
    # Central logger for the Roast application
    class Logger
      extend Forwardable
      VALID_LOG_LEVELS = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"].freeze

      attr_reader :logger, :log_level

      # Delegate info and warn methods to the underlying logger
      def_delegators :logger, :info, :warn

      # Create a specialized debug method that ensures proper functionality
      def debug(message)
        logger.debug(message)
      end

      def error(message)
        # Add any custom error handling logic here
        logger.error(message)
      end

      def fatal(message)
        # Add any custom fatal error handling logic here
        logger.fatal(message)
      end

      def initialize(stdout: $stdout, log_level: ENV["ROAST_LOG_LEVEL"] || "INFO")
        @log_level = validate_log_level(log_level)
        @logger = create_logger(stdout)
      end

      def log_level=(level)
        @log_level = validate_log_level(level)
        logger.level = ::Logger.const_get(@log_level)
      end

      class << self
        extend Forwardable

        def instance
          @instance ||= new
        end

        # Delegate logging methods to the singleton instance
        def_delegators :instance, :debug, :info, :warn, :error, :fatal

        # For testing purposes
        def reset
          @instance = nil
        end
      end

      private

      def validate_log_level(level)
        level_str = level.to_s.upcase
        unless VALID_LOG_LEVELS.include?(level_str)
          raise ArgumentError, "Invalid log level: #{level}. Valid levels are: #{VALID_LOG_LEVELS.join(", ")}"
        end

        level_str
      end

      def create_logger(stdout)
        ::Logger.new(stdout).tap do |logger|
          logger.level = ::Logger.const_get(@log_level)
          logger.formatter = proc do |severity, datetime, _progname, msg|
            msg_string = format_message(msg)

            if severity == "INFO" && !msg_string.start_with?("[")
              msg_string
            else
              "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{severity}: #{msg_string.gsub(/^\[|\]$/, "").strip}\n"
            end
          end
        end
      end

      # Ensures that the message is a string, and if it's an array, it's formatted correctly for the console
      def format_message(msg)
        case msg
        when String
          msg
        when Array
          if msg.first.is_a?(String) && msg.length == 1
            msg.first
          else
            msg.map { |item| item.is_a?(String) ? item : item.inspect.gsub(/^\[|\]$/, "").strip }.join("\n")
          end
        when NilClass
          ""
        else
          msg.to_s
        end
      end
    end
  end
end
