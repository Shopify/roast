# typed: true
# frozen_string_literal: true

module Roast
  class LogFormatter < ::Logger::Formatter
    TTY_FORMAT = "• %.1s, %s\n" #: String
    NON_TTY_FORMAT = "%.1s, [%s] %5s -- %s\n" #: String
    DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N" #: String

    #: (tty: bool) -> void
    def initialize(tty:)
      super()
      @tty = tty
      @rainbow = Rainbow.new.tap { |r| r.enabled = tty }
    end

    def call(severity, time, _progname, msg)
      type = msg.is_a?(Roast::Log::Message) ? msg.type : nil
      line = if @tty
        format(TTY_FORMAT, severity, msg2str(msg))
      else
        format(NON_TTY_FORMAT, severity, time.strftime(DATETIME_FORMAT), severity, msg2str(msg))
      end
      colourize(severity, type, line)
    end

    private

    #: (String, Symbol?, String) -> String
    def colourize(severity, type, line)
      case type
      when :stderr then @rainbow.wrap(line).yellow
      when :stdout then @rainbow.wrap(line)
      else
        case severity
        when "ERROR", "FATAL" then @rainbow.wrap(line).red
        when "WARN" then @rainbow.wrap(line).color("#FF8C00") # orange
        when "INFO" then @rainbow.wrap(line).bright
        when "DEBUG" then @rainbow.wrap(line).faint
        else line
        end
      end
    end

    #: (String | Exception | untyped) -> String
    def msg2str(msg)
      msg = case msg
      when ::String
        msg.strip
      when Roast::Log::Message
        msg.text.strip
      else
        msg
      end
      super(msg)
    end
  end
end
