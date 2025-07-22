# frozen_string_literal: true

require "test_helper"
require "roast/helpers/timeout_handler"

module Roast
  module Helpers
    class TimeoutHandlerTest < ActiveSupport::TestCase
      def setup
        @handler = TimeoutHandler
      end

      test "call runs simple commands successfully" do
        output, exit_status = @handler.call("echo 'hello world'")

        assert_equal "hello world\n", output
        assert_equal 0, exit_status
      end

      test "call captures both stdout and stderr" do
        output, exit_status = @handler.call("echo 'stdout'; echo 'stderr' >&2")

        assert_includes output, "stdout"
        assert_includes output, "stderr"
        assert_equal 0, exit_status
      end

      test "call respects working directory" do
        Dir.mktmpdir do |tmpdir|
          output, exit_status = @handler.call("pwd", working_directory: tmpdir)

          assert_includes output, tmpdir
          assert_equal 0, exit_status
        end
      end

      test "call handles command failures" do
        output, exit_status = @handler.call("exit 42")

        assert_equal "", output
        assert_equal 42, exit_status
      end

      test "call times out long-running commands" do
        start_time = Time.now

        error = assert_raises(Timeout::Error) do
          @handler.call("sleep 5", timeout: 1, grace_period: 0.1)
        end

        elapsed = Time.now - start_time
        assert_operator elapsed, :<, 2.0
        assert_match(/timed out after 1 seconds/, error.message)
      end

      test "timeout error message includes working directory" do
        Dir.mktmpdir do |tmpdir|
          error = assert_raises(Timeout::Error) do
            @handler.call("sleep 3", timeout: 1, working_directory: tmpdir, grace_period: 0.1)
          end

          assert_includes error.message, "sleep 3"
          assert_includes error.message, tmpdir
          assert_includes error.message, "timed out after 1 seconds"
        end
      end

      test "call prevents stdin hanging commands" do
        start_time = Time.now
        output, _ = @handler.call("cat", timeout: 2)
        elapsed = Time.now - start_time

        assert_operator elapsed, :<, 1.0
        assert_equal "", output
      end

      test "process cleanup prevents zombie processes" do
        # This test verifies that long-running processes are properly terminated
        # We can't easily test for zombie processes directly, but we can verify
        # that the timeout mechanism completes quickly and doesn't leave hanging processes
        pids_before = %x(ps aux | grep sleep | grep -v grep | wc -l).to_i

        start_time = Time.now
        assert_raises(Timeout::Error) do
          @handler.call("sleep 10", timeout: 1, grace_period: 0.1)
        end
        elapsed = Time.now - start_time

        # Should timeout quickly (within 1.5 seconds to allow for cleanup)
        assert_operator elapsed, :<, 1.5

        # Give a moment for process cleanup
        sleep(0.2)
        pids_after = %x(ps aux | grep sleep | grep -v grep | wc -l).to_i

        # Should not have increased the number of sleep processes
        assert_operator pids_after, :<=, pids_before
      end

      test "cleanup handles already terminated processes gracefully" do
        # This test ensures our cleanup method doesn't fail when process is already dead
        # We test this indirectly by ensuring short timeouts work reliably
        10.times do
          start_time = Time.now
          assert_raises(Timeout::Error) do
            @handler.call("sleep 2", timeout: 1, grace_period: 0.1)
          end
          elapsed = Time.now - start_time
          assert_operator elapsed, :<, 1.5
        end
      end

      test "validate_timeout returns default for nil input" do
        result = @handler.validate_timeout(nil)
        assert_equal 30, result
      end

      test "validate_timeout returns default for zero input" do
        result = @handler.validate_timeout(0)
        assert_equal 30, result
      end

      test "validate_timeout returns default for negative input" do
        result = @handler.validate_timeout(-5)
        assert_equal 30, result
      end

      test "validate_timeout returns input for valid timeout" do
        result = @handler.validate_timeout(60)
        assert_equal 60, result
      end

      test "has correct default timeout constant" do
        assert_equal 30, TimeoutHandler::DEFAULT_TIMEOUT
      end

      test "has correct default grace period constant" do
        assert_equal 5, TimeoutHandler::DEFAULT_GRACE_PERIOD
      end

      test "timeout validation is used in call" do
        output, exit_status = @handler.call("echo 'validation test'", timeout: -1)

        assert_equal "validation test\n", output
        assert_equal 0, exit_status
      end

      test "call handles non-existent commands gracefully" do
        error = assert_raises(Errno::ENOENT) do
          @handler.call("nonexistent_command_xyz_123", timeout: 1)
        end

        assert_match(/No such file or directory/, error.message)
      end

      test "timeout is reasonably accurate" do
        start_time = Time.now

        assert_raises(Timeout::Error) do
          @handler.call("sleep 10", timeout: 1, grace_period: 0.1)
        end

        elapsed = Time.now - start_time
        assert_operator elapsed, :>=, 0.9
        assert_operator elapsed, :<=, 1.5
      end

      test "quick commands complete before timeout" do
        start_time = Time.now
        output, exit_status = @handler.call("echo 'quick'", timeout: 10)
        elapsed = Time.now - start_time

        assert_equal "quick\n", output
        assert_equal 0, exit_status
        assert_operator elapsed, :<, 1.0
      end

      test "cleanup_process logs debug message for permission denied" do
        # Mock a process that can't be killed due to permissions
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true)
        mock_wait_thr.stubs(:pid).returns(12345)

        # Mock Process.kill to raise EPERM (using negative PID for process group)
        Process.stubs(:kill).with("TERM", -12345).raises(Errno::EPERM)

        # Capture debug logs
        Roast::Helpers::Logger.expects(:debug).with("Could not kill process 12345: Permission denied")

        # Call the private cleanup method (default use_pgroup=true)
        @handler.send(:cleanup_process, mock_wait_thr, true, 0.1)

        # Add assertion to ensure test passes
        assert true
      end

      test "cleanup_process logs debug message for unexpected errors" do
        # Mock a process that raises an unexpected error
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true)
        mock_wait_thr.stubs(:pid).returns(12345)

        # Mock Process.kill to raise an unexpected error (using negative PID for process group)
        unexpected_error = StandardError.new("Something went wrong")
        Process.stubs(:kill).with("TERM", -12345).raises(unexpected_error)

        # Capture debug logs
        Roast::Helpers::Logger.expects(:debug).with("Unexpected error during process cleanup: Something went wrong")

        # Call the private cleanup method (default use_pgroup=true)
        @handler.send(:cleanup_process, mock_wait_thr, true, 0.1)

        # Add assertion to ensure test passes
        assert true
      end

      test "cleanup_process handles ESRCH silently" do
        # Mock a process that's already terminated
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true)
        mock_wait_thr.stubs(:pid).returns(12345)

        # Mock Process.kill to raise ESRCH (process already terminated, using negative PID for process group)
        Process.stubs(:kill).with("TERM", -12345).raises(Errno::ESRCH)

        # Should not log anything for ESRCH
        Roast::Helpers::Logger.expects(:debug).never

        # Call the private cleanup method - should not raise (default use_pgroup=true)
        assert_nothing_raised do
          @handler.send(:cleanup_process, mock_wait_thr, true, 0.1)
        end
      end

      test "call with use_pgroup true spawns process in process group" do
        # Mock Open3.popen3 to capture the options passed
        mock_stdin = mock("stdin")
        mock_stdout = mock("stdout")
        mock_stderr = mock("stderr")
        mock_wait_thr = mock("wait_thr")
        mock_status = mock("status")

        mock_stdin.stubs(:close)
        mock_stdout.stubs(:read).returns("output")
        mock_stderr.stubs(:read).returns("")
        mock_stdout.stubs(:close)
        mock_stderr.stubs(:close)
        mock_wait_thr.stubs(:join)
        mock_wait_thr.stubs(:value).returns(mock_status)
        mock_status.stubs(:exitstatus).returns(0)

        # Expect pgroup: true in options
        Open3.expects(:popen3).with("echo test", { chdir: Dir.pwd, pgroup: true })
          .returns([mock_stdin, mock_stdout, mock_stderr, mock_wait_thr])

        output, exit_status = @handler.call("echo test", use_pgroup: true)

        assert_equal "output", output
        assert_equal 0, exit_status
      end

      test "call with use_pgroup false does not use process group" do
        # Mock Open3.popen3 to capture the options passed
        mock_stdin = mock("stdin")
        mock_stdout = mock("stdout")
        mock_stderr = mock("stderr")
        mock_wait_thr = mock("wait_thr")
        mock_status = mock("status")

        mock_stdin.stubs(:close)
        mock_stdout.stubs(:read).returns("output")
        mock_stderr.stubs(:read).returns("")
        mock_stdout.stubs(:close)
        mock_stderr.stubs(:close)
        mock_wait_thr.stubs(:join)
        mock_wait_thr.stubs(:value).returns(mock_status)
        mock_status.stubs(:exitstatus).returns(0)

        # Expect NO pgroup option in options
        Open3.expects(:popen3).with("echo test", { chdir: Dir.pwd })
          .returns([mock_stdin, mock_stdout, mock_stderr, mock_wait_thr])

        output, exit_status = @handler.call("echo test", use_pgroup: false)

        assert_equal "output", output
        assert_equal 0, exit_status
      end

      test "cleanup_process with use_pgroup true kills process group" do
        # Mock a process that needs to be killed
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true, false) # alive first, then dead after kill
        mock_wait_thr.stubs(:pid).returns(12345)

        # Expect negative PID (kills process group)
        Process.expects(:kill).with("TERM", -12345)

        # Call the private cleanup method with pgroup enabled
        @handler.send(:cleanup_process, mock_wait_thr, true, 0.1)
      end

      test "cleanup_process with use_pgroup false kills individual process" do
        # Mock a process that needs to be killed
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true, false) # alive first, then dead after kill
        mock_wait_thr.stubs(:pid).returns(12345)

        # Expect positive PID (kills individual process)
        Process.expects(:kill).with("TERM", 12345)

        # Call the private cleanup method with pgroup disabled
        @handler.send(:cleanup_process, mock_wait_thr, false, 0.1)
      end

      test "timeout cleanup uses correct pgroup setting" do
        # Test that when use_pgroup is false, cleanup_process is called with false
        # We can't easily mock the private method, so we'll test the behavior indirectly
        # by checking that the process is killed with positive PID (individual process)

        # Mock a process that will timeout
        mock_wait_thr = mock("wait_thr")
        mock_wait_thr.stubs(:alive?).returns(true, true, false) # alive during timeout, alive during cleanup, then dead after kill
        mock_wait_thr.stubs(:pid).returns(12345)

        # Mock stdin/stdout/stderr
        mock_stdin = mock("stdin")
        mock_stdout = mock("stdout")
        mock_stderr = mock("stderr")
        mock_stdin.stubs(:close)
        mock_stdout.stubs(:read).returns("")
        mock_stderr.stubs(:read).returns("")
        mock_stdout.stubs(:close)
        mock_stderr.stubs(:close)
        mock_wait_thr.stubs(:join).raises(Timeout::Error) # Force timeout

        # Mock Open3.popen3
        Open3.stubs(:popen3).returns([mock_stdin, mock_stdout, mock_stderr, mock_wait_thr])

        # Expect positive PID kill (individual process, not process group)
        Process.expects(:kill).with("TERM", 12345) # Positive PID = individual process

        # Should raise timeout error
        assert_raises(Timeout::Error) do
          @handler.call("sleep 5", timeout: 0.1, use_pgroup: false, grace_period: 0.1)
        end

        # Add assertion to ensure test passes
        assert true
      end
    end
  end
end
