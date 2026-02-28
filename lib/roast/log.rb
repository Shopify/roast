# typed: true
# frozen_string_literal: true

module Roast
  # Central logging interface for Roast.
  #
  # Provides a simple, testable logging API that wraps the standard library Logger
  # and leverages Roast's Event framework for clean async task integration with proper task hierarchy attribution.
  # Outputs to STDERR by default.
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
    extend self
    include Kernel

    LOG_LEVELS = {
      DEBUG: ::Logger::DEBUG,
      INFO: ::Logger::INFO,
      WARN: ::Logger::WARN,
      ERROR: ::Logger::ERROR,
      FATAL: ::Logger::FATAL,
    }.freeze #: Hash[Symbol, Integer]

    attr_writer :logger

    #: (String) -> void
    def debug(message)
      Roast::Event << { debug: message }
    end

    #: (String) -> void
    def info(message)
      Roast::Event << { info: message }
    end

    #: (String) -> void
    def warn(message)
      Roast::Event << { warn: message }
    end

    #: (String) -> void
    def error(message)
      Roast::Event << { error: message }
    end

    #: (String) -> void
    def fatal(message)
      Roast::Event << { fatal: message }
    end

    #: (String) -> void
    def unknown(message)
      Roast::Event << { unknown: message }
    end

    #: () -> Logger
    def logger
      @logger ||= create_logger
    end

    #: () -> void
    def reset!
      @logger = nil
    end

    #: () -> bool
    def tty?
      return false unless @logger

      logdev = @logger.instance_variable_get(:@logdev)&.dev
      logdev&.respond_to?(:isatty) && logdev&.isatty
    end

    private

    #: () -> Logger
    def create_logger
      ::Logger.new($stderr, progname: "Roast").tap do |l|
        l.level = LOG_LEVELS.fetch(log_level("INFO"))
        l.formatter = Roast::LogFormatter.new(tty: $stderr.tty?)
      end
    end

    #: (String) -> Symbol
    def log_level(default_level)
      level = (ENV["ROAST_LOG_LEVEL"] || default_level).upcase.to_sym
      raise ArgumentError, "Invalid log level: #{level}. Valid levels are: #{LOG_LEVELS.keys.join(", ")}" unless LOG_LEVELS.key?(level)

      level
    end
  end
end
