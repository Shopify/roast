# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class CommandRunnerTest < ActiveSupport::TestCase
      test "provides stdin_content to running command" do
        stdout, stderr, status = CommandRunner.simple_execute(
          "tr",
          "[:lower:]",
          "[:upper:]",
          stdin_content: "Hello, world!",
        )

        assert_equal "HELLO, WORLD!\n", stdout
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end

      test "basic execution captures stdout" do
        stdout, stderr, status = CommandRunner.simple_execute("echo", "hello")

        assert_equal "hello\n", stdout
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end

      test "captures both stdout and stderr separately" do
        stdout, stderr, status = CommandRunner.simple_execute(
          "bash", "-c", "echo 'to stdout' && echo 'to stderr' >&2"
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

        stdout, _, _ = CommandRunner.simple_execute(
          "bash",
          "-c",
          "echo 'line1' && echo 'line2' && echo 'line3'",
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

        _, stderr, _ = CommandRunner.simple_execute(
          "bash",
          "-c",
          "echo 'err1' >&2 && echo 'err2' >&2 && echo 'err3' >&2",
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

        stdout, stderr, _ = CommandRunner.simple_execute(
          "bash",
          "-c",
          "echo 'out1' && echo 'err1' >&2 && echo 'out2' && echo 'err2' >&2",
          stdout_handler: stdout_mock,
          stderr_handler: stderr_mock,
        )

        stdout_mock.verify
        stderr_mock.verify
        assert_equal "out1\nout2\n", stdout
        assert_equal "err1\nerr2\n", stderr
      end

      test "nil handlers work without errors" do
        stdout, _, _ = CommandRunner.simple_execute(
          "echo",
          "test",
          stdout_handler: nil,
          stderr_handler: nil,
        )

        assert_equal "test\n", stdout
      end

      test "timeout raises TimeoutError" do
        error = assert_raises(CommandRunner::TimeoutError) do
          CommandRunner.simple_execute("sleep", "5", timeout: 0.1)
        end

        assert_match(/timed out after 0.1 seconds/, error.message)
      end

      test "captures non-zero exit status" do
        _, _, status = CommandRunner.simple_execute("bash", "-c", "exit 42")

        assert_equal 42, status.exitstatus
      end

      test "raises Errno::ENOENT for non-existent command" do
        assert_raises(Errno::ENOENT) do
          CommandRunner.simple_execute("nonexistent_command_xyz_12345")
        end
      end

      test "timeout kills the process" do
        start_time = Time.now
        thread = Thread.new do
          CommandRunner.simple_execute("sleep", "100", timeout: 0.1)
        rescue CommandRunner::TimeoutError
          # Expected
        end
        thread.join
        elapsed_time = Time.now - start_time
        assert_operator elapsed_time, :<, 1, "command ran for much longer than configured timeout"
      end

      test "captured output preserved with non-zero exit status" do
        stdout, stderr, status = CommandRunner.simple_execute(
          "bash",
          "-c",
          "echo 'output' && echo 'error' >&2 && exit 42",
        )

        assert_equal "output\n", stdout
        assert_equal "error\n", stderr
        assert_equal 42, status.exitstatus
      end

      test "handlers still work with non-zero exit status" do
        stdout_lines = []
        stderr_lines = []

        _, _, status = CommandRunner.simple_execute(
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

        # Exception should not propagate from handler
        assert_nothing_raised do
          stdout, _, status = CommandRunner.simple_execute(
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

      test "handler exceptions are logged to debug" do
        failing_handler = ->(_line) { raise StandardError, "Test error" }

        # Capture debug calls
        debug_calls = []
        Roast::Helpers::Logger.stub(:debug, ->(msg) { debug_calls << msg }) do
          CommandRunner.simple_execute(
            "echo",
            "test",
            stdout_handler: failing_handler,
          )
        end

        assert_equal 1, debug_calls.size
        assert_match(/stdout_handler raised: StandardError - Test error/, debug_calls.first)
      end

      test "runs command in current working directory if no working directory specified" do
        stdout, stderr, status = CommandRunner.simple_execute("pwd")

        assert_equal "#{Dir.pwd}\n", stdout
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end

      test "runs command in specified working directory if working directory specified" do
        uuid = Random.uuid
        Dir.mktmpdir(["Roast", uuid]) do |dir|
          stdout, stderr, status = CommandRunner.simple_execute("pwd", working_directory: dir)

          assert_match(/Roast.*#{uuid}/, stdout.strip)
          assert_equal "", stderr
          assert_equal 0, status.exitstatus
        end
      end

      test "runs command with PWD environment variable set to specified working directory" do
        uuid = Random.uuid
        Dir.mktmpdir(["Roast", uuid]) do |dir|
          stdout, stderr, status = CommandRunner.execute("echo $PWD", working_directory: dir)

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

        stdout, stderr, status = CommandRunner.simple_execute("echo", nil, "hello", "world", nil)

        assert_equal "hello world\n", stdout
        assert_equal "", stderr
        assert_equal 0, status.exitstatus
      end

      test "raises NoCommandProvidedError when args is empty" do
        assert_raises(CommandRunner::NoCommandProvidedError) do
          CommandRunner.simple_execute
        end
      end

      test "raises NoCommandProvidedError when args contains only nil" do
        assert_raises(CommandRunner::NoCommandProvidedError) do
          CommandRunner.simple_execute(nil, nil)
        end
      end

      test "does not raise NoCommandProvidedError when args contains only empty string" do
        assert_raises(Errno::ENOENT) do
          CommandRunner.simple_execute("")
        end
      end

      test "does not raise NoCommandProvidedError when first value of args is empty string" do
        assert_raises(Errno::ENOENT) do
          CommandRunner.simple_execute("", "echo", "hello")
        end
      end

      # Shell execution tests (execute method)
      test "execute supports shell pipelines" do
        stdout, _, status = CommandRunner.execute("echo 'foo\nbar\nbaz' | grep 'bar'")

        assert_equal "bar\n", stdout
        assert_equal 0, status.exitstatus
      end

      test "execute supports multiple pipes" do
        stdout, _, status = CommandRunner.execute("echo 'line1\nline2\nline3' | grep 'line' | wc -l")

        assert_equal "3", stdout.strip
        assert_equal 0, status.exitstatus
      end

      test "execute supports output redirection" do
        temp_file = "/tmp/roast_test_#{Process.pid}_#{rand(10000)}.txt"

        begin
          stdout, _, status = CommandRunner.execute("echo 'test content' > #{temp_file} && cat #{temp_file}")

          assert_equal "test content\n", stdout
          assert_equal 0, status.exitstatus
          assert File.exist?(temp_file)
          assert_equal "test content\n", File.read(temp_file)
        ensure
          File.delete(temp_file) if File.exist?(temp_file)
        end
      end

      test "execute supports variable expansion" do
        stdout, _, status = CommandRunner.execute("TEST_VAR='hello world' && echo $TEST_VAR")

        assert_equal "hello world\n", stdout
        assert_equal 0, status.exitstatus
      end

      test "execute supports command substitution" do
        stdout, _, status = CommandRunner.execute("echo \"Current directory: $(basename $(pwd))\"")

        assert_match(/Current directory: \w+/, stdout)
        assert_equal 0, status.exitstatus
      end

      test "execute with timeout kills entire process group" do
        # Create a pipeline that spawns multiple processes
        # If process group cleanup works, all processes should be killed
        thread = Thread.new do
          CommandRunner.execute("sleep 100 | grep foo", timeout: 0.1)
        rescue CommandRunner::TimeoutError
          # Expected
        end

        # Give command time to start
        sleep(0.05)

        # Wait for timeout to fire
        thread.join

        # Give kill some time to complete
        sleep(0.15)

        # Verify no sleep or grep processes are still running
        # rubocop:disable Roast/UseCmdRunner
        output = %x(ps aux | grep "sleep 100" | grep -v grep)
        # rubocop:enable Roast/UseCmdRunner
        assert_empty output, "sleep process should be killed after timeout"

        # rubocop:disable Roast/UseCmdRunner
        output2 = %x(ps aux | grep "grep foo" | grep -v grep | grep -v "ps aux")
        # rubocop:enable Roast/UseCmdRunner
        assert_empty output2, "grep process should be killed after timeout"
      end

      test "execute handles complex shell commands" do
        stdout, _, status = CommandRunner.execute(
          "for i in 1 2 3; do echo \"number: $i\"; done | grep '2'",
        )

        assert_equal "number: 2\n", stdout
        assert_equal 0, status.exitstatus
      end

      test "execute preserves exit status from pipeline" do
        _, _, status = CommandRunner.execute("echo 'test' | grep 'nonexistent'")

        assert_equal 1, status.exitstatus
      end

      test "execute works with stderr redirect" do
        _, stderr, status = CommandRunner.execute("echo 'error message' >&2")

        assert_equal "error message\n", stderr
        assert_equal 0, status.exitstatus
      end

      test "execute with handlers works on shell pipelines" do
        lines = []
        stdout, _, _ = CommandRunner.execute(
          "echo 'line1\nline2\nline3' | grep 'line'",
          stdout_handler: ->(line) { lines << line },
        )

        assert_equal ["line1\n", "line2\n", "line3\n"], lines
        assert_equal "line1\nline2\nline3\n", stdout
      end
    end
  end
end
