# frozen_string_literal: true

require "test_helper"

module Roast
  class LogFormatterTest < ActiveSupport::TestCase
    ANSI_PATTERN = /\e\[[0-9;]*m/ #: Regexp

    # --- TTY mode ---

    test "TTY format outputs bullet, severity initial, and message" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 3, 1, 12, 0, 0)

      result = formatter.call("INFO", time, "Roast", "hello world")

      assert_equal "• I, hello world\n", result
    end

    test "TTY format ignores progname and timestamp" do
      formatter = LogFormatter.new(tty: true)
      time1 = Time.new(2026, 1, 1, 0, 0, 0)
      time2 = Time.new(2026, 12, 31, 23, 59, 59)

      result1 = formatter.call("WARN", time1, "Prog1", "msg")
      result2 = formatter.call("WARN", time2, "Prog2", "msg")

      assert_equal result1, result2
    end

    test "TTY format uses first character of severity" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 1, 1)

      assert_match(/^• D,/, formatter.call("DEBUG", time, nil, "msg"))
      assert_match(/^• I,/, formatter.call("INFO", time, nil, "msg"))
      assert_match(/^• W,/, formatter.call("WARN", time, nil, "msg"))
      assert_match(/^• E,/, formatter.call("ERROR", time, nil, "msg"))
      assert_match(/^• F,/, formatter.call("FATAL", time, nil, "msg"))
    end

    # --- Non-TTY mode ---

    test "non-TTY format includes severity, timestamp, and message" do
      formatter = LogFormatter.new(tty: false)
      time = Time.new(2026, 3, 1, 12, 30, 45, in: "+00:00")

      result = formatter.call("INFO", time, "Roast", "hello world")

      assert_match(/^I,/, result)
      assert_includes result, "2026-03-01T12:30:45."
      assert_includes result, "INFO"
      assert_includes result, "hello world"
    end

    test "non-TTY format uses microsecond precision in timestamp" do
      formatter = LogFormatter.new(tty: false)
      time = Time.new(2026, 3, 1, 12, 0, 0.123456, in: "+00:00")

      result = formatter.call("INFO", time, "Roast", "msg")

      assert_match(/2026-03-01T12:00:00\.\d{6}/, result)
    end

    test "non-TTY format includes severity twice (initial and full)" do
      formatter = LogFormatter.new(tty: false)
      time = Time.new(2026, 1, 1)

      result = formatter.call("ERROR", time, nil, "msg")

      assert_match(/^E,/, result)
      assert_includes result, "ERROR"
    end

    test "non-TTY format does not include ANSI escape codes" do
      formatter = LogFormatter.new(tty: false)
      time = Time.new(2026, 1, 1)

      ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"].each do |severity|
        result = formatter.call(severity, time, nil, "msg")
        refute_match ANSI_PATTERN, result, "Expected no ANSI codes for #{severity} in non-TTY mode"
      end
    end

    # --- msg2str ---

    test "strips leading and trailing whitespace from string messages" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "  hello  ")

      assert_includes result, "hello"
      refute_includes result, "  hello  "
    end

    test "adds trailing newline to formatted message" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "no original newline")

      assert_equal "• I, no original newline\n", result
    end

    test "strips leading and trailing newlines and whitespace from string messages" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "\n  hello\n")

      assert_equal "• I, hello\n", result
    end

    test "does not strips internal spaces or newlines from multiline string messages" do
      formatter = no_colour(LogFormatter.new(tty: true))
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "\n  hello\n   \nworld\n")

      assert_equal "• I, hello\n   \nworld\n", result
    end

    test "handles exception messages" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)
      error = RuntimeError.new("boom")

      result = formatter.call("ERROR", time, nil, error)

      assert_includes result, "boom"
    end

    # --- Colourization (TTY mode) ---

    test "INFO messages are bright in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "info msg")

      assert_match ANSI_PATTERN, result
      # \e[1m = bold/bright
      assert_match(/\e\[1m• I, info msg\n/, result)
    end

    test "DEBUG messages are faint in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("DEBUG", time, nil, "debug msg")

      assert_match ANSI_PATTERN, result
      # \e[2m = faint/dim
      assert_match(/\e\[2m/, result)
    end

    test "ERROR messages are red in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("ERROR", time, nil, "error msg")

      assert_match ANSI_PATTERN, result
      # \e[31m = red
      assert_match(/\e\[31m/, result)
    end

    test "FATAL messages are red in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("FATAL", time, nil, "fatal msg")

      assert_match ANSI_PATTERN, result
      assert_match(/\e\[31m/, result)
    end

    test "WARN messages are orange in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("WARN", time, nil, "warn msg")

      assert_match ANSI_PATTERN, result
      # Rainbow uses 38;5;xxx for 256-color or 38;2;r;g;b for truecolor
      assert_match(/(\e\[38;5;214m)|(\e\[38;2;\d+;\d+\d+)/, result)
    end

    test "stderr marker lines are yellow in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "path ❯❯ some error output")

      assert_match ANSI_PATTERN, result
      # \e[33m = yellow
      assert_match(/\e\[33m/, result)
      assert_includes result, "❯❯"
    end

    test "stdout marker lines are not colourized in TTY mode" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "path ❯ some output")

      # Should not have colour codes (stdout lines are wrapped but no colour method called)
      refute_match ANSI_PATTERN, result
      assert_includes result, "❯"
    end

    test "stderr marker takes precedence over severity colour" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      # Even though ERROR would normally be red, ❯❯ should make it yellow
      result = formatter.call("ERROR", time, nil, "path ❯❯ error output")

      assert_match(/\e\[33m/, result) # yellow
      refute_match(/\e\[31m/, result) # not red
    end

    test "stdout marker takes precedence over severity colour" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      # Even though WARN would normally be orange, ❯ should pass through uncoloured
      result = formatter.call("WARN", time, nil, "path ❯ warn output")

      refute_match ANSI_PATTERN, result
    end

    private

    # Disable colours in log formatter output to make it easier to assert on format alone
    #
    #: (Roast::LogFormatter) -> Roast::LogFormatter
    def no_colour(formatter)
      formatter.instance_variable_set(:@rainbow, Rainbow.new.tap { |r| r.enabled = false })
      formatter
    end
  end
end
