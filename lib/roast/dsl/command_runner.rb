# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # The canonical way to execute shell commands in Roast.
    #
    # CommandRunner is the standard command execution interface for DSL cogs
    # and should be used for all command invocations in this project.
    #
    # Features:
    # - Separate stdout/stderr capture (using Async fibers for concurrency)
    # - Line-by-line streaming callbacks for custom handling
    # - Optional timeout support with automatic process cleanup
    # - Direct command execution (no shell by default for safety)
    #
    # Note: Currently executes commands directly without shell features.
    # Shell support (pipes, redirects, etc.) will be added in a future version.
    class CommandRunner
      class CommandRunnerError < StandardError; end

      class NoCommandProvidedError < CommandRunnerError; end

      class TimeoutError < CommandRunnerError; end

      class << self
        # Execute a command with optional stream handlers
        #
        # @param args [Array<String>] Command and arguments as an array
        # @param timeout [Integer, nil] Timeout in seconds (default: nil, no timeout)
        # @param stdout_handler [Proc, nil] Called for each stdout line
        # @param stderr_handler [Proc, nil] Called for each stderr line
        # @return [Array<String, String, Process::Status>] stdout, stderr, status
        #
        # @example Basic usage
        #   stdout, stderr, status = CommandRunner.execute(["echo", "hello"])
        #
        # @example With handlers for streaming output
        #   CommandRunner.execute(
        #     ["ls", "-la"],
        #     stdout_handler: ->(line) { puts "[OUT] #{line}" }
        #   )
        #
        # @example With explicit timeout
        #   CommandRunner.execute(["sleep", "5"], timeout: 2)  # Will timeout after 2 seconds
        #: (
        #|  Array[String],
        #|  ?working_directory: (Pathname | String)?,
        #|  ?timeout: (Integer | Float)?,
        #|  ?stdin_content: String?,
        #|  ?stdout_handler: untyped,
        #|  ?stderr_handler: untyped
        #| ) -> [String, String, Process::Status]
        def execute(
          args,
          working_directory: nil,
          timeout: nil,
          stdin_content: nil,
          stdout_handler: nil,
          stderr_handler: nil
        )
          pid = nil #: Integer?
          wait_thread = nil #: Thread?

          begin
            stdin, stdout, stderr, wait_thread = Open3 #: as untyped
              .popen3(
                { "PWD" => working_directory&.to_s }.compact,
                *args,
                { chdir: working_directory }.compact,
              )
            stdin.puts stdin_content if stdin_content.present?
            stdin.close
            pid = wait_thread.pid

            # If timeout is specified, start a timer in a separate thread
            timeout_thread = if timeout
              Thread.new do
                sleep(timeout)
                kill_process(pid) if pid
              end
            end

            # Read stdout and stderr concurrently
            stdout_content, stderr_content = Async do
              stdout_task = Async do
                buffer = "" #: String
                stdout.each_line do |line|
                  buffer += line
                  begin
                    stdout_handler&.call(line)
                  rescue => e
                    Roast::Helpers::Logger.debug("stdout_handler raised: #{e.class} - #{e.message}")
                  end
                end
                buffer
              rescue IOError
                buffer
              end

              stderr_task = Async do
                buffer = "" #: String
                stderr.each_line do |line|
                  buffer += line
                  begin
                    stderr_handler&.call(line)
                  rescue => e
                    Roast::Helpers::Logger.debug("stderr_handler raised: #{e.class} - #{e.message}")
                  end
                end
                buffer
              rescue IOError
                buffer
              end

              [stdout_task.wait, stderr_task.wait]
            end.wait

            # Wait for the process to complete
            status = wait_thread.value

            # Cancel the timeout thread if it's still running
            timeout_thread&.kill

            # Check if the process was killed due to timeout
            if timeout && status.signaled? && (status.termsig == 15 || status.termsig == 9)
              raise TimeoutError, "Command timed out after #{timeout} seconds"
            end

            [stdout_content, stderr_content, status]
          ensure
            # Clean up resources
            begin
              [stdout, stderr].compact.each(&:close)
            rescue
              nil
            end
            # If we haven't waited for the process yet, kill it
            if pid && wait_thread&.alive?
              kill_process(pid)
              wait_thread.join(1) # Give it a second to finish
            end
          end #: as [String, String, Process::Status]
        end

        private

        #: (Integer) -> void
        def kill_process(pid)
          return unless process_running?(pid)

          # First try TERM signal
          Process.kill("TERM", pid)

          # Give process a short time to terminate gracefully
          5.times do
            sleep(0.02)
            return unless process_running?(pid)
          end

          # If still running, use KILL signal
          Process.kill("KILL", pid) if process_running?(pid)

          # Also try to kill the process group to ensure child processes are killed
          begin
            Process.kill("-KILL", pid)
          rescue
            nil
          end
        rescue Errno::ESRCH
          # Process already terminated
        rescue Errno::EPERM
          Roast::Helpers::Logger.debug("Could not kill process #{pid}: Permission denied")
        end

        #: (Integer) -> bool
        def process_running?(pid)
          Process.getpgid(pid)
          true
        rescue Errno::ESRCH
          false
        end
      end
    end
  end
end
