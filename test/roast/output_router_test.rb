# frozen_string_literal: true

require "test_helper"

module Roast
  class OutputRouterTest < ActiveSupport::TestCase
    setup do
      EventMonitor.reset!
      OutputRouter.disable!
    end

    teardown do
      OutputRouter.disable!
    end

    # --- enabled? ---

    test "enabled? returns false initially" do
      refute_predicate OutputRouter, :enabled?
    end

    test "enabled? returns true after enable!" do
      OutputRouter.enable!

      assert_predicate OutputRouter, :enabled?
    end

    test "enabled? returns false after disable!" do
      OutputRouter.enable!
      assert_predicate OutputRouter, :enabled?
      OutputRouter.disable!

      refute_predicate OutputRouter, :enabled?
    end

    # --- enable! ---

    test "enable! returns true on first call" do
      assert_equal true, OutputRouter.enable!
    end

    test "enable! returns false when already enabled" do
      OutputRouter.enable!

      assert_equal false, OutputRouter.enable!
    end

    test "enable! adds write_without_roast method to stdout" do
      OutputRouter.enable!

      assert $stdout.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
    end

    test "enable! adds write_without_roast method to stderr" do
      OutputRouter.enable!

      assert $stderr.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
    end

    # --- disable! ---

    test "disable! returns false when not enabled" do
      assert_equal false, OutputRouter.disable!
    end

    test "disable! returns true when enabled" do
      OutputRouter.enable!

      assert_equal true, OutputRouter.disable!
    end

    test "disable! removes write_without_roast method from stdout" do
      OutputRouter.enable!
      assert $stdout.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
      OutputRouter.disable!

      refute $stdout.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
    end

    test "disable! removes write_without_roast method from stderr" do
      OutputRouter.enable!
      assert $stderr.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
      OutputRouter.disable!

      refute $stderr.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
    end

    # --- output_fiber? / mark_as_output_fiber! ---

    test "mark_as_output_fiber! makes output_fiber? return true for current fiber" do
      OutputRouter.mark_as_output_fiber!

      assert_predicate OutputRouter, :output_fiber?
    end

    test "output_fiber? is false for a different fiber" do
      OutputRouter.mark_as_output_fiber!

      other_fiber_result = nil
      Fiber.new { other_fiber_result = OutputRouter.output_fiber? }.resume

      refute other_fiber_result
    end

    # --- stdout/stderr routing ---

    test "write on stdout routes to Event when not output fiber" do
      OutputRouter.enable!
      # Mark a different fiber as the output fiber
      other_fiber = Fiber.new { OutputRouter.mark_as_output_fiber! }
      other_fiber.resume

      Event.expects(:<<).with { |payload| payload[:stdout] == "test output" }

      $stdout.write("test output")
    end

    test "write on stderr routes to Event when not output fiber" do
      OutputRouter.enable!
      other_fiber = Fiber.new { OutputRouter.mark_as_output_fiber! }
      other_fiber.resume

      Event.expects(:<<).with { |payload| payload[:stderr] == "test error" }

      $stderr.write("test error")
    end

    test "write on stdout passes through when on output fiber" do
      OutputRouter.enable!
      OutputRouter.mark_as_output_fiber!

      Event.expects(:<<).never

      _stdout, _stderr = capture_io do
        $stdout.write("passthrough output")
      end
    end

    test "write on stderr passes through when on output fiber" do
      OutputRouter.enable!
      OutputRouter.mark_as_output_fiber!

      Event.expects(:<<).never

      _stdout, _stderr = capture_io do
        $stderr.write("passthrough error")
      end
    end

    # --- WRITE_WITHOUT_ROAST constant ---

    test "WRITE_WITHOUT_ROAST is defined" do
      assert_equal :write_without_roast, OutputRouter::WRITE_WITHOUT_ROAST
    end

    # --- write_without_roast ---

    test "write_without_roast is removed after disable!" do
      OutputRouter.enable!
      assert $stdout.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
      assert $stderr.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)

      OutputRouter.disable!

      refute $stdout.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
      refute $stderr.respond_to?(OutputRouter::WRITE_WITHOUT_ROAST)
    end

    test "write is restored to original behaviour after disable!" do
      original_stdout_write = $stdout.method(:write)
      original_stderr_write = $stderr.method(:write)

      OutputRouter.enable!
      OutputRouter.disable!

      assert_equal original_stdout_write.unbind, $stdout.method(:write).unbind
      assert_equal original_stderr_write.unbind, $stderr.method(:write).unbind
    end
  end
end
