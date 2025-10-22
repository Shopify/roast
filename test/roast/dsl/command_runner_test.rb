# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class CommandRunnerTest < ActiveSupport::TestCase
      test "basic execution captures stdout" do
        stdout, stderr, status = CommandRunner.execute("echo", "hello")

        assert_equal "hello\n", stdout
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end

      test "captures both stdout and stderr separately" do
        stdout, stderr, status = CommandRunner.execute(
          "bash", "-c", "echo 'to stdout' && echo 'to stderr' >&2"
        )

        assert_equal "to stdout\n", stdout
        assert_equal "to stderr\n", stderr
        assert_equal 0, status.exitstatus
      end

      test "stdout_handler is called for each line" do
        lines = []
        stdout, _, _ = CommandRunner.execute(
          "echo",
          "test",
          stdout_handler: ->(line) { lines << line },
        )

        assert_equal ["test\n"], lines
        assert_equal "test\n", stdout
      end

      test "stderr_handler is called for each line" do
        lines = []
        _, stderr, _ = CommandRunner.execute(
          "bash",
          "-c",
          "echo 'error' >&2",
          stderr_handler: ->(line) { lines << line },
        )

        assert_equal ["error\n"], lines
        assert_equal "error\n", stderr
      end

      test "both handlers work together" do
        stdout_lines = []
        stderr_lines = []

        stdout, stderr, _ = CommandRunner.execute(
          "bash",
          "-c",
          "echo 'out' && echo 'err' >&2",
          stdout_handler: ->(line) { stdout_lines << line },
          stderr_handler: ->(line) { stderr_lines << line },
        )

        assert_equal ["out\n"], stdout_lines
        assert_equal ["err\n"], stderr_lines
        assert_equal "out\n", stdout
        assert_equal "err\n", stderr
      end

      test "nil handlers work without errors" do
        stdout, _, _ = CommandRunner.execute(
          "echo",
          "test",
          stdout_handler: nil,
          stderr_handler: nil,
        )

        assert_equal "test\n", stdout
      end

      test "timeout raises TimeoutError" do
        error = assert_raises(CommandRunner::TimeoutError) do
          CommandRunner.execute("sleep", "5", timeout: 0.1)
        end

        assert_match(/timed out after 0.1 seconds/, error.message)
      end

      test "captures non-zero exit status" do
        _, _, status = CommandRunner.execute("bash", "-c", "exit 42")

        assert_equal 42, status.exitstatus
      end

      test "raises Errno::ENOENT for non-existent command" do
        assert_raises(Errno::ENOENT) do
          CommandRunner.execute("nonexistent_command_xyz_12345")
        end
      end

      test "tracks and untracks child processes" do
        # Get baseline count
        initial_count = CommandRunner.send(:all_child_processes).size

        # Execute command
        CommandRunner.execute("echo", "test")

        # Should be untracked after completion
        final_count = CommandRunner.send(:all_child_processes).size
        assert_equal initial_count, final_count
      end

      test "cleanup_all_children terminates tracked processes" do
        # Spawn a long-running process in a thread so we can verify cleanup
        thread = Thread.new do
          CommandRunner.execute("sleep", "10", timeout: 10)
        rescue CommandRunner::TimeoutError
          # Expected when we kill it
        end

        # Give it time to start
        sleep(0.1)

        # Should have one tracked process
        processes = CommandRunner.send(:all_child_processes)
        assert_equal 1, processes.size, "Should have exactly one tracked process"

        pid = processes.keys.first
        assert CommandRunner.send(:process_running?, pid), "Process should be running"

        # Clean up all children
        CommandRunner.cleanup_all_children

        # Give cleanup time to complete
        sleep(0.1)

        # Process should be terminated
        refute CommandRunner.send(:process_running?, pid), "Process should be terminated"

        # Should be untracked
        processes = CommandRunner.send(:all_child_processes)
        assert_equal 0, processes.size, "Should have no tracked processes"

        # Clean up thread
        thread.kill if thread.alive?
      end

      test "timeout cleans up the process" do
        # Execute a command that will timeout
        error = assert_raises(CommandRunner::TimeoutError) do
          CommandRunner.execute("sleep", "10", timeout: 0.1)
        end

        assert_match(/timed out after 0.1 seconds/, error.message)

        # Give cleanup time to complete
        sleep(0.1)

        # Should have no tracked processes after timeout
        processes = CommandRunner.send(:all_child_processes)
        assert_equal 0, processes.size, "Process should be untracked after timeout"
      end

      test "multiple line output calls handler for each line" do
        lines = []
        stdout, _, _ = CommandRunner.execute(
          "bash",
          "-c",
          "echo 'line1' && echo 'line2' && echo 'line3'",
          stdout_handler: ->(line) { lines << line },
        )

        assert_equal ["line1\n", "line2\n", "line3\n"], lines
        assert_equal "line1\nline2\nline3\n", stdout
      end

      test "handlers still work with non-zero exit status" do
        stdout_lines = []
        stderr_lines = []

        _, _, status = CommandRunner.execute(
          "bash",
          "-c",
          "echo 'output' && echo 'error' >&2 && exit 1",
          stdout_handler: ->(line) { stdout_lines << line },
          stderr_handler: ->(line) { stderr_lines << line },
        )

        assert_equal ["output\n"], stdout_lines
        assert_equal ["error\n"], stderr_lines
        assert_equal 1, status.exitstatus
      end

      test "handler exceptions don't break command execution" do
        stdout_lines = []

        # Handler that raises on second call
        call_count = 0
        failing_handler = ->(line) do
          call_count += 1
          stdout_lines << line
          raise "Handler error!" if call_count == 2
        end

        stdout, _, status = CommandRunner.execute(
          "bash",
          "-c",
          "echo 'line1' && echo 'line2' && echo 'line3'",
          stdout_handler: failing_handler,
        )

        # Should still capture all output even though handler crashed
        assert_equal "line1\nline2\nline3\n", stdout
        # Handler was called for all 3 lines (even after exception)
        assert_equal 3, stdout_lines.size
        assert_equal 0, status.exitstatus
      end
    end
  end
end
