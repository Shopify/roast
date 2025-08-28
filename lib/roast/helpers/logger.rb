# typed: true
# frozen_string_literal: true

module Roast
  module Helpers
    # IO-like wrapper that always delegates to the current $stdout
    # This ensures test frameworks like capture_io can properly intercept output
    # Logger only requires write and close methods, not full IO interface
    class StdoutWrapper
      def write(string)
        $stdout.write(string)
      end

      def close
        # No-op - we don't actually close stdout
      end

      def flush
        $stdout.flush
      end

      def sync=(value)
        $stdout.sync = value
      end

      def sync
        $stdout.sync
      end
    end

    # Central logger for the Roast application
    class Logger
      VALID_LOG_LEVELS = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"].freeze #: Array[String]

      delegate :debug, :info, :warn, :error, :fatal, to: :@logger

      attr_reader :logger

      class << self
        delegate :debug, :info, :warn, :error, :fatal, to: :instance

        #: -> Roast::Helpers::Logger
        def instance
          @instance ||= new
        end

        #: -> void
        def reset
          @instance = nil
        end
      end

      private

      def initialize(log_level: ENV["ROAST_LOG_LEVEL"] || "INFO")
        @log_level = validate_log_level(log_level)
        @logger = create_logger
      end

      def validate_log_level(level)
        level_str = level.to_s.upcase
        unless VALID_LOG_LEVELS.include?(level_str)
          raise ArgumentError, "Invalid log level: #{level}. Valid levels are: #{VALID_LOG_LEVELS.join(", ")}"
        end

        level_str
      end

      def create_logger
        # Use a custom IO wrapper that always delegates to the current $stdout
        # This ensures capture_io in tests can properly intercept output
        stdout_wrapper = StdoutWrapper.new
        ::Logger.new(stdout_wrapper).tap do |logger|
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
