# frozen_string_literal: true

require "timeout"
require "open3"

module Roast
  module Helpers
    # Shared timeout handling logic for command-based tools
    #
    # This class provides centralized timeout functionality for executing shell commands
    # with proper process management and resource cleanup.
    #
    # @example Basic usage
    #   output, status = TimeoutHandler.call("echo hello", timeout: 5)
    #
    # @example With custom working directory
    #   output, status = TimeoutHandler.call("pwd", timeout: 10, working_directory: "/tmp")
    #
    # @example With custom grace period
    #   output, status = TimeoutHandler.call("sleep 10", timeout: 10, grace_period: 1)
    #
    # @example Disable process group for TTY commands (like macOS security)
    #   output, status = TimeoutHandler.call("security find-generic-password", timeout: 30, use_pgroup: false)
    class TimeoutHandler
      DEFAULT_TIMEOUT = 30
      DEFAULT_GRACE_PERIOD = 5

      class << self
        # Execute a command with timeout using Open3 with proper process cleanup
        # @param command [String] The command to execute
        # @param timeout [Integer] Timeout in seconds
        # @param working_directory [String] Directory to execute in (default: Dir.pwd)
        # @param use_pgroup [Boolean] Whether to spawn process in its own process group (default: true)
        # @return [Array<String, Integer>] [output, exit_status]
        # @raise [Timeout::Error] When command exceeds timeout duration
        def call(command, timeout: DEFAULT_TIMEOUT, working_directory: Dir.pwd, grace_period: DEFAULT_GRACE_PERIOD, use_pgroup: true)
          timeout = validate_timeout(timeout)
          output = ""
          exit_status = nil
          wait_thr = nil

          begin
            Timeout.timeout(timeout) do
              popen3_options = { chdir: working_directory }
              popen3_options[:pgroup] = true if use_pgroup
              stdin, stdout, stderr, wait_thr = Open3.popen3(command, popen3_options)
              stdin.close # Prevent hanging on stdin-waiting commands
              output = stdout.read + stderr.read
              wait_thr.join
              exit_status = wait_thr.value.exitstatus

              [stdout, stderr].each(&:close)
            end
          rescue Timeout::Error
            # Clean up any remaining processes to prevent zombies
            cleanup_process(wait_thr, use_pgroup, grace_period) if wait_thr&.alive?
            raise Timeout::Error, "Command '#{command}' in '#{working_directory}' timed out after #{timeout} seconds"
          end

          [output, exit_status]
        end

        # Validate and normalize timeout value
        # @param timeout [Integer, nil] Raw timeout value
        # @return [Integer] Default timeout if timeout is nil or less than 0
        def validate_timeout(timeout)
          timeout.nil? || timeout <= 0 ? DEFAULT_TIMEOUT : timeout
        end

        private

        # Clean up process on timeout to prevent zombie processes
        # @param wait_thr [Process::Waiter] The process thread to clean up
        # @param use_pgroup [Boolean] Whether to kill the process group (default: true)
        # @param grace_period [Integer] Grace period in seconds before force kill (default: DEFAULT_GRACE_PERIOD)
        def cleanup_process(wait_thr, use_pgroup = true, grace_period = DEFAULT_GRACE_PERIOD)
          return unless wait_thr&.alive?

          pid = wait_thr.pid
          # Use negative PID to kill process group, positive PID for individual process
          target_pid = use_pgroup ? -pid : pid
          # First try graceful termination
          Process.kill("TERM", target_pid)
          sleep(grace_period)

          # Force kill if still alive
          if wait_thr.alive?
            Process.kill("KILL", target_pid)
          end
        rescue Errno::ESRCH
          # Process already terminated, which is fine
        rescue Errno::EPERM
          # Permission denied - process may be owned by different user
          Roast::Helpers::Logger.debug("Could not kill process #{pid}: Permission denied")
        rescue => e
          # Catch any other unexpected errors during cleanup
          Roast::Helpers::Logger.debug("Unexpected error during process cleanup: #{e.message}")
        end
      end
    end
  end
end
