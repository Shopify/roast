# frozen_string_literal: true

require "test_helper"

module Roast
  class EventMonitorTest < ActiveSupport::TestCase
    setup do
      EventMonitor.reset!
    end

    teardown do
      EventMonitor.reset!
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
      event = Event.new([], { info: "direct message" })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "direct message"
    end

    test "accept queues event for async handling when running" do
      handler_fiber = nil
      caller_fiber = nil

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

      assert_includes @logger_output.string, "queued message"
      assert_not_nil handler_fiber, "Expected event to be handled"
      assert_not_equal caller_fiber, handler_fiber, "Expected event to be handled on a different fiber (the consumer), not the caller"
    end

    # --- Event handler routing ---

    test "handle_log_event routes log events to the logger" do
      event = Event.new([], { debug: "debug message" })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "debug message"
    end

    test "handle_begin_event logs cog begin events" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el, cog_el], { begin: cog_el })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "test_cog(:step1) Starting"
    end

    test "handle_end_event logs cog end events" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el, cog_el], { end: cog_el })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "test_cog(:step1) Complete"
    end

    test "handle_begin_event does not log cog message for execution manager begin" do
      em_el = mock_execution_manager_path_element
      event = Event.new([em_el], { begin: em_el })
      EventMonitor.accept(event)

      refute_match(/test_cog/, @logger_output.string)
    end

    test "handle_end_event does not log cog message for execution manager end" do
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el], { end: em_el })
      EventMonitor.accept(event)

      refute_match(/test_cog/, @logger_output.string)
    end

    # --- handle_begin_workflow_event ---

    test "handle_begin_workflow_event logs workflow starting when path length is 1" do
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el], { begin: em_el })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "Workflow Starting"
    end

    test "handle_begin_workflow_event logs workflow context at debug level" do
      em_el = mock_execution_manager_path_element(
        workflow_context: create_workflow_context(
          targets: ["file.rb"],
          args: [:verbose],
          kwargs: { dry_run: "true" },
          tmpdir: "/tmp/roast123",
          workflow_dir: "/home/workflows/my_workflow",
        ),
      )
      event = Event.new([em_el], { begin: em_el })

      with_log_level("DEBUG") { EventMonitor.accept(event) }

      assert_includes @logger_output.string, "Workflow Context"
      assert_includes @logger_output.string, "file.rb"
      assert_includes @logger_output.string, "verbose"
      assert_includes @logger_output.string, "dry_run"
      assert_includes @logger_output.string, "/tmp/roast123"
      assert_includes @logger_output.string, "/home/workflows/my_workflow"
    end

    test "handle_begin_workflow_event is not triggered when path length is greater than 1" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el, cog_el], { begin: cog_el })
      EventMonitor.accept(event)

      refute_includes @logger_output.string, "Workflow Starting"
    end

    # --- handle_end_event workflow ---

    test "handle_end_event logs workflow complete when path length is 1" do
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el], { end: em_el })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "Workflow Complete"
    end

    test "handle_end_event does not log workflow complete when path length is greater than 1" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)
      em_el = mock_execution_manager_path_element

      event = Event.new([em_el, cog_el], { end: cog_el })
      EventMonitor.accept(event)

      refute_includes @logger_output.string, "Workflow Complete"
    end

    # --- format_path ---

    test "format_path formats named cog as type(:name)" do
      cog = TestCogSupport::TestCog.new(:my_step, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)

      event = Event.new([cog_el], { begin: cog_el })
      result = EventMonitor.send(:format_path, event)

      assert_equal "test_cog(:my_step)", result
    end

    test "format_path formats anonymous cog as type only" do
      cog = TestCogSupport::TestCog.new(nil, nil, anonymous: true)
      cog_el = TaskContext::PathElement.new(cog: cog)

      event = Event.new([cog_el], { begin: cog_el })
      result = EventMonitor.send(:format_path, event)

      assert_match(/\Atest_cog\z/, result)
    end

    test "format_path formats execution manager with scope" do
      em_el = mock_execution_manager_path_element(scope: :items, scope_index: 3)

      event = Event.new([em_el], { begin: em_el })
      result = EventMonitor.send(:format_path, event)

      assert_equal "{:items}[3]", result
    end

    test "format_path omits execution manager without scope" do
      em_el = mock_execution_manager_path_element(scope: nil, scope_index: 0)

      event = Event.new([em_el], { begin: em_el })
      result = EventMonitor.send(:format_path, event)

      assert_equal "", result
    end

    test "format_path joins multiple path elements with arrow" do
      em_el = mock_execution_manager_path_element(scope: :files, scope_index: 0)
      cog = TestCogSupport::TestCog.new(:analyze, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)

      event = Event.new([em_el, cog_el], { begin: cog_el })
      result = EventMonitor.send(:format_path, event)

      assert_equal "{:files}[0] -> test_cog(:analyze)", result
    end

    test "format_path skips unscopeed execution manager in mixed path" do
      em_el = mock_execution_manager_path_element(scope: nil, scope_index: 0)
      cog = TestCogSupport::TestCog.new(:step, nil)
      cog_el = TaskContext::PathElement.new(cog: cog)

      event = Event.new([em_el, cog_el], { begin: cog_el })
      result = EventMonitor.send(:format_path, event)

      assert_equal "test_cog(:step)", result
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
      event = Event.new([], { custom_type: "data" })
      EventMonitor.accept(event)

      assert_includes @logger_output.string, "custom_type"
    end

    # --- Time stubbing ---

    test "handle_event preserves event time when dispatching" do
      frozen_time = Time.new(2026, 1, 1, 12, 0, 0)
      event = Event.new([], { info: "timed" })
      event.instance_variable_set(:@time, frozen_time)

      logged_time = nil
      Roast::Log.logger.formatter = proc { |_severity, time, _progname, _msg|
        logged_time = time
        ""
      }

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

    private

    #: (?scope: Symbol?, ?scope_index: Integer, ?workflow_context: WorkflowContext?)
    def mock_execution_manager_path_element(scope: nil, scope_index: 0, workflow_context: nil)
      TaskContext::PathElement.new(execution_manager: mock_execution_manager(scope:, scope_index:, workflow_context:))
    end
  end
end
