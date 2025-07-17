# frozen_string_literal: true

module Roast
  module Helpers
    # Central logger for the Roast application
    class Logger
      VALID_LOG_LEVELS = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"].freeze

      delegate_missing_to :@logger

      attr_reader :logger

      class << self
        delegate_missing_to :instance

        def instance
          @instance ||= new
        end

        # Override Kernel#warn to ensure proper delegation
        def warn(*args)
          instance.warn(*args)
        end

        # For testing purposes
        def reset
          @instance = nil
        end
      end

      private

      def initialize(stdout: $stdout, log_level: ENV["ROAST_LOG_LEVEL"] || "INFO")
        @log_level = validate_log_level(log_level)
        @logger = create_logger(stdout)
      end

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
              msg_string + "\n"
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
