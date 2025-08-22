# frozen_string_literal: true

require "test_helper"

module Roast
  module Helpers
    # NOTE: Lean towards speed over thoroughness here. Long running commands and timeouts over 0.5s are to be avoided.
    class CmdRunnerTest < ActiveSupport::TestCase
      test "all methods run without timeout when no timeout is passed" do
        Timeout.expects(:timeout).never
        run_all_methods("echo 'test'", popen3_sans_block: true)
      end

      test "all methods track child processes" do
        CmdRunner.expects(:track_child_process).times(6)
        run_all_methods("echo 'hello world'", popen3_sans_block: true)
      end

      test "all methods cleanup child processes" do
        # Only 5 because we don't expect cleanup when invoking popen3 without a block
        CmdRunner.expects(:cleanup_child_process).times(5)
        run_all_methods("echo 'hello world'", popen3_sans_block: true)
      end

      test "all methods do timeout" do
        all_methods.each do |method|
          start_time = Time.now

          assert_raises(Timeout::Error) do
            method.call("sleep 0.5", timeout: 0.1) { |*_io, wait_thr| wait_thr.join }
          end

          elapsed = Time.now - start_time
          assert_operator elapsed, :<, 0.5
        end
      end

      test "all methods do timeout validation" do
        all_methods.each do |method|
          assert_raises(ArgumentError) do
            method.call("sleep 0.5", timeout: -1)
          end

          assert_raises(ArgumentError) do
            method.call("sleep 0.5", timeout: 0)
          end

          assert_raises(ArgumentError) do
            method.call("sleep 0.5", timeout: CmdRunner::MAX_TIMEOUT + 1)
          end
        end
      end

      test "all methods complete before timeout for quick commands" do
        all_methods(popen3: false).each do |method|
          start_time = Time.now
          method.call("echo 'quick'", timeout: 0.5)
          elapsed = Time.now - start_time
          assert_operator elapsed, :<, 0.5
        end
      end

      test "capture3 captures both stdout and stderr" do
        stdout, stderr, status = CmdRunner.capture3("echo 'stdout'; echo 'stderr' >&2")
        output = stdout + stderr

        assert_includes output, "stdout"
        assert_includes output, "stderr"
        assert_equal 0, status.exitstatus
      end

      test "all capture methods handle command failures" do
        all_capture_methods.each do |method|
          *_stdout_stderr, status = method.call("exit 42")
          assert_equal 42, status.exitstatus
        end
      end

      test "all methods but popen3 handle stdin hanging commands" do
        all_methods(popen3: false).each do |method|
          start_time = Time.now
          method.call("cat", timeout: 0.5)
          elapsed = Time.now - start_time
          assert_operator elapsed, :<, 0.5
        end
      end

      test "all methods but popen3 handle non-existent commands gracefully" do
        all_methods(popen3: false).each do |method|
          error = assert_raises(Errno::ENOENT) do
            method.call("nonexistent_command_xyz_123", timeout: 1)
          end

          assert_match(/No such file or directory/, error.message)
        end
      end

      test "popen3 raises ArgumentError if you pass a timeout without a block" do
        error = assert_raises(ArgumentError) do
          CmdRunner.popen3("echo test", timeout: 1)
        end

        assert_equal "Timeout provided but no block given", error.message
      end

      test "cleanup_all_children cleans up all tracked processes" do
        fake_processes = {
          12345 => { command: "echo test1", started_at: Time.now },
          12346 => { command: "echo test2", started_at: Time.now },
          12347 => { command: "echo test3", started_at: Time.now },
        }

        CmdRunner.expects(:all_child_processes).returns(fake_processes)

        CmdRunner.expects(:cleanup_child_process).with(12345)
        CmdRunner.expects(:cleanup_child_process).with(12346)
        CmdRunner.expects(:cleanup_child_process).with(12347)

        Roast::Helpers::Logger.expects(:info).times(3)

        CmdRunner.cleanup_all_children
      end

      test "cleanup_all_children handles empty process list" do
        # Mock empty child processes
        CmdRunner.expects(:all_child_processes).returns({})

        # Should not call cleanup_child_process at all
        CmdRunner.expects(:cleanup_child_process).never

        # Call cleanup_all_children - should exit early
        CmdRunner.cleanup_all_children
      end

      test "popen3 returns the value of the block if given a block" do
        result = CmdRunner.popen3("echo test") do |stdin, stdout, _stderr, _wait_thr|
          stdin.close
          output = stdout.read
          "custom_return_value: #{output.strip}"
        end

        assert_equal "custom_return_value: test", result
      end

      test "popen3 returns stdin, stdout, stderr, wait_thr when not given a block" do
        stdin, stdout, stderr, wait_thr = CmdRunner.popen3("echo test")

        stdin.close
        output = stdout.read.strip
        wait_thr.join
        stdout.close
        stderr.close
        stdin.close

        assert_equal "test", output
        assert_instance_of IO, stdin
        assert_instance_of IO, stdout
        assert_instance_of IO, stderr
        assert_instance_of Process::Waiter, wait_thr
      end

      test "popen3 tracks child processes regardless of if it's provided a block" do
        CmdRunner.expects(:track_child_process).twice

        CmdRunner.popen3("echo test") do |stdin, stdout, _stderr, _wait_thr|
          stdin.close
          stdout.read
        end

        stdin, stdout, stderr, wait_thr = CmdRunner.popen3("echo test")
        stdin.close
        stdout.close
        stderr.close
        wait_thr.join
      end

      test "popen3 cleans up child processes if given a block" do
        # Test with block - should cleanup
        CmdRunner.expects(:cleanup_child_process).once
        CmdRunner.popen3("echo test") do |stdin, stdout, _stderr, _wait_thr|
          stdin.close
          stdout.read
        end

        # Test without block - should NOT cleanup
        CmdRunner.expects(:cleanup_child_process).never
        stdin, stdout, _stderr, wait_thr = CmdRunner.popen3("echo test")
        stdin.close
        stdout.read
        wait_thr.join
      end

      test "normalize_timeout returns original value for valid timeouts" do
        assert_equal 15, CmdRunner.normalize_timeout(15)
        assert_equal 60, CmdRunner.normalize_timeout(60)
        assert_equal 1800, CmdRunner.normalize_timeout(1800)
      end

      test "normalize_timeout returns DEFAULT_TIMEOUT for non-positive values" do
        assert_equal CmdRunner::DEFAULT_TIMEOUT, CmdRunner.normalize_timeout(nil)
        assert_equal CmdRunner::DEFAULT_TIMEOUT, CmdRunner.normalize_timeout(0)
        assert_equal CmdRunner::DEFAULT_TIMEOUT, CmdRunner.normalize_timeout(-1)
        assert_equal CmdRunner::DEFAULT_TIMEOUT, CmdRunner.normalize_timeout(-100)
      end

      test "normalize_timeout caps at MAX_TIMEOUT for excessive values" do
        assert_equal CmdRunner::MAX_TIMEOUT, CmdRunner.normalize_timeout(5000)
        assert_equal CmdRunner::MAX_TIMEOUT, CmdRunner.normalize_timeout(10000)
        assert_equal CmdRunner::MAX_TIMEOUT, CmdRunner.normalize_timeout(CmdRunner::MAX_TIMEOUT + 1)
        assert_equal CmdRunner::MAX_TIMEOUT, CmdRunner.normalize_timeout(CmdRunner::MAX_TIMEOUT)
      end

      private

      def all_capture_methods
        all_methods(popen3: false).select { |method| method.name.to_s.start_with?("capture") }
      end

      def all_methods(popen3: true)
        [
          CmdRunner.method(:system),
          CmdRunner.method(:capture2),
          CmdRunner.method(:capture2e),
          CmdRunner.method(:capture3),
        ] + (popen3 ? [CmdRunner.method(:popen3)] : [])
      end

      def run_all_methods(*args, **options)
        popen3_sans_block = options.delete(:popen3_sans_block)

        all_methods.each do |method|
          if method.name == :popen3
            method.call(*args, **options) { |*_io, wait_thr| wait_thr.join }
            if popen3_sans_block
              *io, wait_thr = method.call(*args, **options)
              io.each(&:close)
              wait_thr.join
            end
          else
            method.call(*args, **options)
          end
        end
      end
    end
  end
end
