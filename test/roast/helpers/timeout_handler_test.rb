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
          @handler.call("sleep 5", timeout: 1)
        end

        elapsed = Time.now - start_time
        assert_operator elapsed, :<, 2.0
        assert_match(/timed out after 1 seconds/, error.message)
      end

      test "timeout error message includes working directory" do
        Dir.mktmpdir do |tmpdir|
          error = assert_raises(Timeout::Error) do
            @handler.call("sleep 3", timeout: 1, working_directory: tmpdir)
          end

          assert_includes error.message, "sleep 3"
          assert_includes error.message, tmpdir
          assert_includes error.message, "timed out after 1 seconds"
        end
      end

      test "call prevents stdin hanging commands" do
        start_time = Time.now
        output, exit_status = @handler.call("cat", timeout: 2)
        elapsed = Time.now - start_time

        assert_operator elapsed, :<, 1.0
        assert_equal "", output
      end

      test "process cleanup prevents zombie processes" do
        # This test verifies that long-running processes are properly terminated
        # We can't easily test for zombie processes directly, but we can verify
        # that the timeout mechanism completes quickly and doesn't leave hanging processes
        pids_before = `ps aux | grep sleep | grep -v grep | wc -l`.to_i

        start_time = Time.now
        assert_raises(Timeout::Error) do
          @handler.call("sleep 10", timeout: 1)
        end
        elapsed = Time.now - start_time

        # Should timeout quickly (within 1.5 seconds to allow for cleanup)
        assert_operator elapsed, :<, 1.5

        # Give a moment for process cleanup
        sleep(0.2)
        pids_after = `ps aux | grep sleep | grep -v grep | wc -l`.to_i

        # Should not have increased the number of sleep processes
        assert_operator pids_after, :<=, pids_before
      end

      test "cleanup handles already terminated processes gracefully" do
        # This test ensures our cleanup method doesn't fail when process is already dead
        # We test this indirectly by ensuring short timeouts work reliably
        10.times do
          start_time = Time.now
          assert_raises(Timeout::Error) do
            @handler.call("sleep 2", timeout: 1)
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

      test "validate_timeout caps timeout at maximum" do
        result = @handler.validate_timeout(500)
        assert_equal 300, result
      end

      test "validate_timeout allows exactly maximum timeout" do
        result = @handler.validate_timeout(300)
        assert_equal 300, result
      end

      test "has correct default timeout constant" do
        assert_equal 30, TimeoutHandler::DEFAULT_TIMEOUT
      end

      test "has correct maximum timeout constant" do
        assert_equal 300, TimeoutHandler::MAX_TIMEOUT
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
          @handler.call("sleep 10", timeout: 1)
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
    end
  end
end
