# frozen_string_literal: true

require "test_helper"

module Roast
  class CommandRunnerTest < ActiveSupport::TestCase
    test "provides stdin_content to running command" do
      stdout, stderr, status = CommandRunner.execute(
        ["tr", "[:lower:]", "[:upper:]"],
        stdin_content: "Hello, world!",
      )

      assert_equal "HELLO, WORLD!\n", stdout
      assert_equal "", stderr
      assert_equal 0, status.exitstatus
    end

    test "basic execution captures stdout" do
      stdout, stderr, status = CommandRunner.execute(["echo", "hello"])

      assert_equal "hello\n", stdout
      assert_equal "", stderr
      assert_equal 0, status.exitstatus
    end

    test "captures both stdout and stderr separately" do
      stdout, stderr, status = CommandRunner.execute(
        ["bash", "-c", "echo 'to stdout' && echo 'to stderr' >&2"],
      )

      assert_equal "to stdout\n", stdout
      assert_equal "to stderr\n", stderr
      assert_equal 0, status.exitstatus
    end

    test "stdout_handler is called for each line" do
      mock_handler = Minitest::Mock.new
      mock_handler.expect(:call, nil, ["line1\n"])
      mock_handler.expect(:call, nil, ["line2\n"])
      mock_handler.expect(:call, nil, ["line3\n"])

      stdout, _, _ = CommandRunner.execute(
        ["bash", "-c", "echo 'line1' && echo 'line2' && echo 'line3'"],
        stdout_handler: mock_handler,
      )

      mock_handler.verify
      assert_equal "line1\nline2\nline3\n", stdout
    end

    test "stderr_handler is called for each line" do
      mock_handler = Minitest::Mock.new
      mock_handler.expect(:call, nil, ["err1\n"])
      mock_handler.expect(:call, nil, ["err2\n"])
      mock_handler.expect(:call, nil, ["err3\n"])

      _, stderr, _ = CommandRunner.execute(
        ["bash", "-c", "echo 'err1' >&2 && echo 'err2' >&2 && echo 'err3' >&2"],
        stderr_handler: mock_handler,
      )

      mock_handler.verify
      assert_equal "err1\nerr2\nerr3\n", stderr
    end

    test "both handlers work together" do
      stdout_mock = Minitest::Mock.new
      stderr_mock = Minitest::Mock.new
      stdout_mock.expect(:call, nil, ["out1\n"])
      stdout_mock.expect(:call, nil, ["out2\n"])
      stderr_mock.expect(:call, nil, ["err1\n"])
      stderr_mock.expect(:call, nil, ["err2\n"])

      stdout, stderr, _ = CommandRunner.execute(
        ["bash", "-c", "echo 'out1' && echo 'err1' >&2 && echo 'out2' && echo 'err2' >&2"],
        stdout_handler: stdout_mock,
        stderr_handler: stderr_mock,
      )

      stdout_mock.verify
      stderr_mock.verify
      assert_equal "out1\nout2\n", stdout
      assert_equal "err1\nerr2\n", stderr
    end

    test "nil handlers work without errors" do
      stdout, _, _ = CommandRunner.execute(
        ["echo", "test"],
        stdout_handler: nil,
        stderr_handler: nil,
      )

      assert_equal "test\n", stdout
    end

    test "timeout raises TimeoutError" do
      error = assert_raises(CommandRunner::TimeoutError) do
        CommandRunner.execute(["sleep", "5"], timeout: 0.1)
      end

      assert_match(/timed out after 0.1 seconds/, error.message)
    end

    test "captures non-zero exit status" do
      _, _, status = CommandRunner.execute(["bash", "-c", "exit 42"])

      assert_equal 42, status.exitstatus
    end

    test "raises Errno::ENOENT for non-existent command" do
      assert_raises(Errno::ENOENT) do
        CommandRunner.execute(["nonexistent_command_xyz_12345"])
      end
    end

    test "timeout kills the process" do
      time = Benchmark.realtime do
        # Capture PID in a thread
        thread = Thread.new do
          CommandRunner.execute(["sleep", "5"], timeout: 0.1)
        rescue CommandRunner::TimeoutError
          # Expected
        end

        # Give command time to start
        sleep(0.05)

        # Wait for timeout to fire
        thread.join

        # Give kill some time to complete
        sleep(0.15)

        # The sleep process should be dead
        # We can't easily get the PID from outside, but we can verify
        # that a very short timeout doesn't leave sleep running
        # by checking process list (external check, not using CommandRunner)
        output = %x(ps aux | grep "sleep 2" | grep -v grep)
        assert_empty output, "sleep process should be killed after timeout"
      end
      assert_operator time, :<, 1, "command ran for much longer than configured timeout"
    end

    test "captured output preserved with non-zero exit status" do
      stdout, stderr, status = CommandRunner.execute(
        ["bash", "-c", "echo 'output' && echo 'error' >&2 && exit 42"],
      )

      assert_equal "output\n", stdout
      assert_equal "error\n", stderr
      assert_equal 42, status.exitstatus
    end

    test "handlers still work with non-zero exit status" do
      stdout_lines = []
      stderr_lines = []

      _, _, status = CommandRunner.execute(
        ["bash", "-c", "echo 'output' && echo 'error' >&2 && exit 1"],
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

      # Exception should not propagate from handler
      assert_nothing_raised do
        stdout, _, status = CommandRunner.execute(
          ["bash", "-c", "echo 'line1' && echo 'line2' && echo 'line3'"],
          stdout_handler: failing_handler,
        )

        # Should still capture all output even though handler crashed
        assert_equal "line1\nline2\nline3\n", stdout
        # Handler was called for all 3 lines (even after exception)
        assert_equal 3, stdout_lines.size
        assert_equal 0, status.exitstatus
      end
    end

    test "handler exceptions are written to stderr" do
      failing_handler = ->(_line) { raise StandardError, "Test error" }

      with_log_level("DEBUG") do
        _, stderr = capture_io do
          CommandRunner.execute(
            ["echo", "test"],
            stdout_handler: failing_handler,
          )
        end

        assert_match(/stdout_handler raised: StandardError - Test error/, stderr)
      end
    end

    test "runs command in current working directory if no working directory specified" do
      stdout, stderr, status = CommandRunner.execute(["pwd"])

      assert_equal "#{Dir.pwd}\n", stdout
      assert_equal "", stderr
      assert_equal 0, status.exitstatus
    end

    test "runs command in specified working directory if working directory specified" do
      uuid = Random.uuid
      Dir.mktmpdir(["Roast", uuid]) do |dir|
        stdout, stderr, status = CommandRunner.execute(["pwd"], working_directory: dir)

        assert_match(/Roast.*#{uuid}/, stdout.strip)
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end
    end

    test "runs command with PWD environment variable set to specified working directory" do
      uuid = Random.uuid
      Dir.mktmpdir(["Roast", uuid]) do |dir|
        stdout, stderr, status = CommandRunner.execute(["echo $PWD"], working_directory: dir)

        assert_match(/Roast.*#{uuid}/, stdout.strip)
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end
    end

    test "removes nils from command args" do
      mock_stdin = mock.tap { |it| it.expects(:close).returns(nil) }
      mock_status = mock.tap { |it| it.expects(:exitstatus).returns(0) }
      mock_wait_thread = mock.tap do |it|
        it.expects(:pid).returns(12345).at_least_once
        it.expects(:value).returns(mock_status).at_least_once
        it.expects(:alive?).returns(false)
      end
      Open3.stubs(:popen3).with({}, "echo", "hello", "world", {}).returns([mock_stdin, "hello world\n", "", mock_wait_thread])

      stdout, stderr, status = CommandRunner.execute(["echo", nil, "hello", "world", nil])

      assert_equal "hello world\n", stdout
      assert_equal "", stderr
      assert_equal 0, status.exitstatus
    end

    test "raises NoCommandProvidedError when args is empty" do
      assert_raises(CommandRunner::NoCommandProvidedError) do
        CommandRunner.execute([])
      end
    end

    test "raises NoCommandProvidedError when args contains only nil" do
      assert_raises(CommandRunner::NoCommandProvidedError) do
        CommandRunner.execute([nil, nil])
      end
    end

    test "does not raise NoCommandProvidedError when args contains only empty string" do
      assert_raises(Errno::ENOENT) do
        CommandRunner.execute([""])
      end
    end

    test "does not raise NoCommandProvidedError when first value of args is empty string" do
      assert_raises(Errno::ENOENT) do
        CommandRunner.execute(["", "echo", "hello"])
      end
    end
  end
end
