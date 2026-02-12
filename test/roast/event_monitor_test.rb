# frozen_string_literal: true

require "test_helper"

module Roast
  class EventMonitorTest < ActiveSupport::TestCase
    setup do
      EventMonitor.reset!
      Roast::Log.reset!
    end

    teardown do
      EventMonitor.reset!
      Roast::Log.reset!
    end

    # --- Error classes ---

    test "EventMonitorError is a StandardError" do
      assert EventMonitor::EventMonitorError < StandardError
    end

    test "EventMonitorAlreadyStartedError is an EventMonitorError" do
      assert EventMonitor::EventMonitorAlreadyStartedError < EventMonitor::EventMonitorError
    end

    test "EventMonitorNotRunningError is an EventMonitorError" do
      assert EventMonitor::EventMonitorNotRunningError < EventMonitor::EventMonitorError
    end

    # --- running? ---

    test "running? returns false initially" do
      refute_predicate EventMonitor, :running?
    end

    test "running? returns true after start!" do
      Sync do
        EventMonitor.start!

        assert_predicate EventMonitor, :running?
      end
    end

    test "running? returns false after stop!" do
      Sync do
        EventMonitor.start!
        assert_predicate EventMonitor, :running?
        EventMonitor.stop!

        refute_predicate EventMonitor, :running?
      end
    end

    # --- start! ---

    test "start! raises EventMonitorAlreadyStartedError when already running" do
      Sync do
        EventMonitor.start!

        assert_raises(EventMonitor::EventMonitorAlreadyStartedError) do
          EventMonitor.start!
        end
      ensure
        EventMonitor.reset!
      end
    end

    test "start! enables OutputRouter" do
      Sync do
        refute_predicate OutputRouter, :enabled?
        EventMonitor.start!
        assert_predicate OutputRouter, :enabled?
      end
    end

    # --- stop! ---

    test "stop! raises EventMonitorNotRunningError when not running" do
      assert_raises(EventMonitor::EventMonitorNotRunningError) do
        EventMonitor.stop!
      end
    end

    test "stop! disables OutputRouter" do
      Sync do
        EventMonitor.start!
        assert_predicate OutputRouter, :enabled?
        EventMonitor.stop!
        refute_predicate OutputRouter, :enabled?
      end
    end

    # --- reset! ---

    test "reset! stops the monitor without raising if monitor is already stopped" do
      refute_predicate EventMonitor, :running?
      assert_nothing_raised do
        EventMonitor.reset!
      end
      refute_predicate EventMonitor, :running?
    end

    test "reset! stops a running monitor" do
      Sync do
        EventMonitor.start!
        EventMonitor.reset!

        refute_predicate EventMonitor, :running?
      end
    end

    # --- accept ---

    test "accept handles event directly when not running" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      event = Event.new([], { info: "direct message" })
      EventMonitor.accept(event)

      assert_includes output.string, "direct message"
    end

    test "accept queues event for async handling when running" do
      handler_fiber = nil
      caller_fiber = nil

      _, stderr = capture_io do
        Sync do
          EventMonitor.start!

          # Temporarily intercept handle_log_event to record which fiber processes it
          original_method = EventMonitor.method(:handle_log_event)
          EventMonitor.singleton_class.silence_redefinition_of_method(:handle_log_event)
          EventMonitor.define_singleton_method(:handle_log_event) do |event|
            handler_fiber = Fiber.current
            original_method.call(event)
          end

          caller_fiber = Fiber.current
          event = Event.new([], { info: "queued message" })
          EventMonitor.accept(event)

          EventMonitor.stop!
        ensure
          # Restore original
          EventMonitor.singleton_class.silence_redefinition_of_method(:handle_log_event)
          EventMonitor.define_singleton_method(:handle_log_event, original_method) if original_method.present?
        end
      end

      assert_includes stderr, "queued message"
      assert_not_nil handler_fiber, "Expected event to be handled"
      assert_not_equal caller_fiber, handler_fiber, "Expected event to be handled on a different fiber (the consumer), not the caller"
    end

    # --- Event handler routing ---

    test "handle_log_event routes log events to the logger" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output, level: Logger::DEBUG)

      event = Event.new([], { debug: "debug message" })
      EventMonitor.accept(event)

      assert_includes output.string, "debug message"
    end

    test "handle_begin_event logs begin events at debug level" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output, level: Logger::DEBUG)

      event = Event.new([:workflow], { begin: :step1 })
      EventMonitor.accept(event)

      assert_includes output.string, "begin"
    end

    test "handle_end_event logs end events at debug level" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output, level: Logger::DEBUG)

      event = Event.new([:workflow], { end: :step1 })
      EventMonitor.accept(event)

      assert_includes output.string, "end"
    end

    test "handle_stdout_event outputs to puts" do
      event = Event.new([], { stdout: "hello stdout" })

      output = capture_io { EventMonitor.accept(event) }.first

      assert_includes output, "hello stdout"
    end

    test "handle_stderr_event outputs to puts" do
      event = Event.new([], { stderr: "hello stderr" })

      output = capture_io { EventMonitor.accept(event) }.first

      assert_includes output, "hello stderr"
    end

    test "handle_unknown_event logs unrecognized events at unknown level" do
      output = StringIO.new
      Roast::Log.logger = Logger.new(output)

      event = Event.new([], { custom_type: "data" })
      EventMonitor.accept(event)

      assert_includes output.string, "custom_type"
    end

    # --- Time stubbing ---

    test "handle_event preserves event time when dispatching" do
      frozen_time = Time.new(2026, 1, 1, 12, 0, 0)
      event = Event.new([], { info: "timed" })
      event.instance_variable_set(:@time, frozen_time)

      logged_time = nil
      output = StringIO.new
      logger = Logger.new(output)
      logger.formatter = proc { |_severity, time, _progname, _msg|
        logged_time = time
        ""
      }
      Roast::Log.logger = logger

      EventMonitor.accept(event)

      assert_equal frozen_time, logged_time
    end

    # --- with_stubbed_class_method_returning ---

    test "with_stubbed_class_method_returning temporarily overrides a class method" do
      assert_instance_of Time, Time.now

      EventMonitor.send(:with_stubbed_class_method_returning, Time, :now, :fake_value) do
        assert_equal :fake_value, Time.now
      end

      assert_instance_of Time, Time.now
    end

    test "with_stubbed_class_method_returning restores the original method even on exception" do
      begin
        EventMonitor.send(:with_stubbed_class_method_returning, Time, :now, :fake) do
          raise "boom"
        end
      rescue RuntimeError
        # expected
      end

      assert_instance_of Time, Time.now
    end
  end
end
