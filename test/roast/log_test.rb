# frozen_string_literal: true

require "test_helper"

module Roast
  class LogTest < ActiveSupport::TestCase
    setup do
      Roast::Log.reset!
      EventMonitor.reset!
    end

    teardown do
      Roast::Log.reset!
      EventMonitor.reset!
    end

    # --- Event integration ---

    test "debug emits a debug event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:debug] == "debug msg" }
      Roast::Log.debug("debug msg")
    end

    test "info emits an info event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:info] == "info msg" }
      Roast::Log.info("info msg")
    end

    test "warn emits a warn event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:warn] == "warn msg" }
      Roast::Log.warn("warn msg")
    end

    test "error emits an error event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:error] == "error msg" }
      Roast::Log.error("error msg")
    end

    test "fatal emits a fatal event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:fatal] == "fatal msg" }
      Roast::Log.fatal("fatal msg")
    end

    test "unknown emits an unknown event via Event.<<" do
      EventMonitor.expects(:accept).with { |e| e[:unknown] == "unknown msg" }
      Roast::Log.unknown("unknown msg")
    end

    # --- End-to-end: events reach the logger when monitor is not running ---

    test "allows custom logger" do
      custom_output = StringIO.new
      custom_logger = Logger.new(custom_output)

      Roast::Log.logger = custom_logger
      Roast::Log.info("custom logger test")

      assert_includes custom_output.string, "custom logger test"
    end

    test "reset! clears the logger" do
      custom_output = StringIO.new
      Roast::Log.logger = Logger.new(custom_output)

      Roast::Log.reset!

      _stdout, stderr = capture_io do
        Roast::Log.info("after reset")
      end

      refute_includes custom_output.string, "after reset"
      assert_includes stderr, "after reset"
    end

    test "raises ArgumentError for invalid log level" do
      assert_raises(ArgumentError) do
        with_log_level("INVALID") do
          capture_io do
            Roast::Log.info("test")
          end
        end
      end
    end

    # --- End-to-end: events reach the logger through the running event monitor ---

    test "info reaches the logger through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      Sync do
        EventMonitor.start!
        Roast::Log.info("async info message")
        EventMonitor.stop!
      end

      assert_includes output.string, "async info message"
    end

    test "debug reaches the logger through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output, level: Logger::DEBUG)

      Sync do
        EventMonitor.start!
        Roast::Log.debug("async debug message")
        EventMonitor.stop!
      end

      assert_includes output.string, "async debug message"
    end

    test "warn reaches the logger through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      Sync do
        EventMonitor.start!
        Roast::Log.warn("async warn message")
        EventMonitor.stop!
      end

      assert_includes output.string, "async warn message"
    end

    test "error reaches the logger through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      Sync do
        EventMonitor.start!
        Roast::Log.error("async error message")
        EventMonitor.stop!
      end

      assert_includes output.string, "async error message"
    end

    test "fatal reaches the logger through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      Sync do
        EventMonitor.start!
        Roast::Log.fatal("async fatal message")
        EventMonitor.stop!
      end

      assert_includes output.string, "async fatal message"
    end

    test "multiple messages arrive in order through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      Sync do
        EventMonitor.start!
        Roast::Log.info("first")
        Roast::Log.info("second")
        Roast::Log.info("third")
        EventMonitor.stop!
      end

      positions = ["first", "second", "third"].map { |msg| output.string.index(msg) }
      assert positions.all?(&:present?), "Expected all messages in output: #{output.string}"
      assert_equal positions, positions.sort
    end

    test "log severity is respected through a running event monitor" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output, level: Logger::WARN)

      Sync do
        EventMonitor.start!
        Roast::Log.debug("should be filtered")
        Roast::Log.info("also filtered")
        Roast::Log.warn("should appear")
        EventMonitor.stop!
      end

      refute_includes output.string, "should be filtered"
      refute_includes output.string, "also filtered"
      assert_includes output.string, "should appear"
    end

    test "custom logger receives messages through a running event monitor" do
      custom_output = StringIO.new
      Roast::Log.logger = Logger.new(custom_output)

      Sync do
        EventMonitor.start!
        Roast::Log.info("custom async test")
        EventMonitor.stop!
      end

      assert_includes custom_output.string, "custom async test"
    end

    # --- Logger creation ---

    test "logger creates a Logger writing to stderr by default" do
      _stdout, stderr = capture_io do
        Roast::Log.logger.info("default output test")
      end

      assert_includes stderr, "default output test"
    end

    test "logger uses ROAST_LOG_LEVEL env var" do
      with_log_level("ERROR") do
        StringIO.new
        Roast::Log.logger = nil # force re-creation won't work, need to use logger directly
        Roast::Log.reset!
        logger = Roast::Log.logger

        assert_equal Logger::ERROR, logger.level
      end
    end

    test "LOG_LEVELS contains all standard levels" do
      expected = Logger::Severity.const_get(:LEVELS).except("unknown").transform_keys { |k| k.upcase.to_sym } # rubocop:disable Sorbet/ConstantsFromStrings
      assert_equal expected, Roast::Log::LOG_LEVELS
    end
  end
end
