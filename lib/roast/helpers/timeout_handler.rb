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
    class TimeoutHandler
      DEFAULT_TIMEOUT = 30
      MAX_TIMEOUT = 3600

      class << self
        # Execute a command with timeout using Open3 with proper process cleanup
        # @param command [String] The command to execute
        # @param timeout [Integer] Timeout in seconds
        # @param working_directory [String] Directory to execute in (default: Dir.pwd)
        # @return [Array<String, Integer>] [output, exit_status]
        # @raise [Timeout::Error] When command exceeds timeout duration
        def call(command, timeout: DEFAULT_TIMEOUT, working_directory: Dir.pwd)
          timeout = validate_timeout(timeout)
          output = ""
          exit_status = nil
          wait_thr = nil

          begin
            Timeout.timeout(timeout) do
              stdin, stdout, stderr, wait_thr = Open3.popen3(command, chdir: working_directory)
              stdin.close # Prevent hanging on stdin-waiting commands
              output = stdout.read + stderr.read
              wait_thr.join
              exit_status = wait_thr.value.exitstatus

              [stdout, stderr].each(&:close)
            end
          rescue Timeout::Error
            # Clean up any remaining processes to prevent zombies
            cleanup_process(wait_thr) if wait_thr&.alive?
            raise Timeout::Error, "Command '#{command}' in '#{working_directory}' timed out after #{timeout} seconds"
          end

          [output, exit_status]
        end

        # Validate and normalize timeout value
        # @param timeout [Integer, nil] Raw timeout value
        # @return [Integer] Validated timeout between 1 and MAX_TIMEOUT
        def validate_timeout(timeout)
          return DEFAULT_TIMEOUT if timeout.nil? || timeout <= 0

          [timeout, MAX_TIMEOUT].min
        end

        private

        # Clean up process on timeout to prevent zombie processes
        # @param wait_thr [Process::Waiter] The process thread to clean up
        def cleanup_process(wait_thr)
          return unless wait_thr&.alive?

          pid = wait_thr.pid
          # First try graceful termination
          Process.kill("TERM", pid)
          sleep(0.1)

          # Force kill if still alive
          if wait_thr.alive?
            Process.kill("KILL", pid)
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
