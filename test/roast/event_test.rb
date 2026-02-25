# frozen_string_literal: true

require "test_helper"

module Roast
  class EventTest < ActiveSupport::TestCase
    setup do
      EventMonitor.reset!
    end

    teardown do
      EventMonitor.reset!
    end

    # --- Initialization ---

    test "initializes with path, payload, and records time" do
      path = [:workflow, :step1]
      payload = { info: "hello" }

      event = Event.new(path, payload)

      assert_equal [:workflow, :step1], event.path
      assert_equal({ info: "hello" }, event.payload)
      assert_instance_of Time, event.time
    end

    # --- Delegate methods ---

    test "delegates [] to payload" do
      event = Event.new([], { info: "msg" })

      assert_equal "msg", event[:info]
    end

    test "delegates key? to payload" do
      event = Event.new([], { warn: "caution" })

      assert event.key?(:warn)
      refute event.key?(:info)
    end

    test "delegates keys to payload" do
      event = Event.new([], { error: "bad", fatal: "worse" })

      assert_equal [:error, :fatal], event.keys
    end

    # --- Type detection ---

    test "type returns :log for debug payload" do
      event = Event.new([], { debug: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :log for info payload" do
      event = Event.new([], { info: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :log for warn payload" do
      event = Event.new([], { warn: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :log for error payload" do
      event = Event.new([], { error: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :log for fatal payload" do
      event = Event.new([], { fatal: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :log for unknown payload" do
      event = Event.new([], { unknown: "msg" })

      assert_equal :log, event.type
    end

    test "type returns :begin for begin payload" do
      event = Event.new([], { begin: :step1 })

      assert_equal :begin, event.type
    end

    test "type returns :end for end payload" do
      event = Event.new([], { end: :step1 })

      assert_equal :end, event.type
    end

    test "type returns :stdout for stdout payload" do
      event = Event.new([], { stdout: "output" })

      assert_equal :stdout, event.type
    end

    test "type returns :stderr for stderr payload" do
      event = Event.new([], { stderr: "error output" })

      assert_equal :stderr, event.type
    end

    test "type returns :unknown for unrecognized payload" do
      event = Event.new([], { custom: "data" })

      assert_equal :unknown, event.type
    end

    test "type prioritizes log type over other types" do
      event = Event.new([], { info: "msg", begin: :step })

      assert_equal :log, event.type
    end

    # --- Log severity ---

    test "log_severity returns DEBUG for debug log" do
      event = Event.new([], { debug: "msg" })

      assert_equal Logger::DEBUG, event.log_severity
    end

    test "log_severity returns INFO for info log" do
      event = Event.new([], { info: "msg" })

      assert_equal Logger::INFO, event.log_severity
    end

    test "log_severity returns WARN for warn log" do
      event = Event.new([], { warn: "msg" })

      assert_equal Logger::WARN, event.log_severity
    end

    test "log_severity returns ERROR for error log" do
      event = Event.new([], { error: "msg" })

      assert_equal Logger::ERROR, event.log_severity
    end

    test "log_severity returns FATAL for fatal log" do
      event = Event.new([], { fatal: "msg" })

      assert_equal Logger::FATAL, event.log_severity
    end

    test "log_severity returns UNKNOWN for unknown log" do
      event = Event.new([], { unknown: "msg" })

      assert_equal Logger::Severity.const_get(:LEVELS)["unknown"], event.log_severity # rubocop:disable Sorbet/ConstantsFromStrings
    end

    test "log_severity returns WARN for stderr events" do
      event = Event.new([], { stderr: "err" })

      assert_equal Logger::WARN, event.log_severity
    end

    test "log_severity returns INFO for non-log event types" do
      event = Event.new([], { begin: :step })

      assert_equal Logger::INFO, event.log_severity
    end

    # --- Log message ---

    test "log_message returns the message for a log event" do
      event = Event.new([], { info: "hello world" })

      assert_equal "hello world", event.log_message
    end

    test "log_message returns empty string for non-log events" do
      event = Event.new([], { begin: :step })

      assert_equal "", event.log_message
    end

    test "log_message returns empty string when log value is nil" do
      event = Event.new([], { info: nil })

      assert_equal "", event.log_message
    end

    test "log_message returns message for most severe matching log key" do
      event = Event.new([], { debug: "debug msg", error: "error msg" })

      assert_equal "error msg", event.log_message
    end

    # --- Class method << ---

    test "Event.<< creates event and passes to EventMonitor.accept" do
      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) && event[:info] == "test message"
      end

      Event << { info: "test message" }
    end

    test "Event.<< captures current TaskContext path" do
      Fiber[:path] = [:workflow, :step1]

      EventMonitor.expects(:accept).with do |event|
        event.path == [:workflow, :step1]
      end

      Event << { info: "test" }
    ensure
      Fiber[:path] = nil
    end
  end
end
