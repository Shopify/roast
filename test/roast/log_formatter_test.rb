# frozen_string_literal: true

require "test_helper"

module Roast
  class LogFormatterTest < ActiveSupport::TestCase
    # --- TTY mode ---

    test "TTY format outputs bullet, severity initial, and message" do
      formatter = LogFormatter.new(tty: true)
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
      formatter = LogFormatter.new(tty: true)
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

    # --- msg2str ---

    test "strips leading and trailing whitespace from string messages" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "  hello  ")

      assert_includes result, "hello"
      refute_includes result, "  hello  "
    end

    test "adds trailing newline to formatted message" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "no original newline")

      assert_equal "• I, no original newline\n", result
    end

    test "strips leading and trailing newlines and whitespace from string messages" do
      formatter = LogFormatter.new(tty: true)
      time = Time.new(2026, 1, 1)

      result = formatter.call("INFO", time, nil, "\n  hello\n")

      assert_equal "• I, hello\n", result
    end

    test "does not strips internal spaces or newlines from multiline string messages" do
      formatter = LogFormatter.new(tty: true)
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

    # --- Constants ---

    test "DATETIME_FORMAT matches ISO 8601 with microseconds" do
      assert_equal "%Y-%m-%dT%H:%M:%S.%6N", LogFormatter::DATETIME_FORMAT
    end
  end
end
