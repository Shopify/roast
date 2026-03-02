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
    end

    def call(severity, time, _progname, msg)
      if @tty
        format(TTY_FORMAT, severity, msg2str(msg))
      else
        format(NON_TTY_FORMAT, severity, time.strftime(DATETIME_FORMAT), severity, msg2str(msg))
      end
    end

    private

    #: (String | Exception | untyped) -> String
    def msg2str(msg)
      msg = case msg
      when ::String
        msg.strip
      else
        msg
      end
      super(msg)
    end
  end
end
