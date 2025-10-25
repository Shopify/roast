# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Simple command runner for DSL cogs
    #
    # Provides command execution with:
    # - Separate stdout/stderr capture (using Async fibers for concurrency)
    # - Line-by-line callbacks for custom handling
    # - Optional timeout support
    class CommandRunner
      class CommandRunnerError < StandardError; end
      class TimeoutError < CommandRunnerError; end

      class << self
        # Execute a command with optional stream handlers
        #
        # @param command [String] Command to execute
        # @param args [Array<String>] Command arguments (default: [])
        # @param timeout [Integer, nil] Timeout in seconds (default: nil, no timeout)
        # @param stdout_handler [Proc, nil] Called for each stdout line
        # @param stderr_handler [Proc, nil] Called for each stderr line
        # @return [Array<String, String, Process::Status>] stdout, stderr, status
        #
        # @example Basic usage
        #   stdout, stderr, status = CommandRunner.execute("echo", "hello")
        #
        # @example With handlers for streaming output
        #   CommandRunner.execute(
        #     "ls", "-la",
        #     stdout_handler: ->(line) { puts "[OUT] #{line}" }
        #   )
        #
        # @example With explicit timeout
        #   CommandRunner.execute("sleep", "5", timeout: 2)  # Will timeout after 2 seconds
        #: (*untyped, ?timeout: Integer?, ?stdout_handler: untyped, ?stderr_handler: untyped) -> [String, String, Process::Status]
        def execute(*args, timeout: nil, stdout_handler: nil, stderr_handler: nil)
          args = args #: as untyped
          stdout_content = "" #: String
          stderr_content = "" #: String
          pid = nil #: Integer?

          execute_block = lambda do |_sec = nil|
            # rubocop:disable Roast/UseCmdRunner
            Open3.popen3(*args) do |stdin, stdout, stderr, wait_thread|
              # rubocop:enable Roast/UseCmdRunner
              stdin.close
              pid = wait_thread.pid

              # Read stdout and stderr concurrently using Async fibers
              stdout_content, stderr_content = Async do
                stdout_task = Async do
                  buffer = "" #: String
                  stdout.each_line do |line|
                    buffer += line
                    begin
                      stdout_handler&.call(line)
                    rescue => e
                      # Handler exception shouldn't break command execution
                      Roast::Helpers::Logger.debug("stdout_handler raised: #{e.class} - #{e.message}")
                    end
                  end
                  buffer
                rescue IOError
                  # Stream closed, normal
                  buffer
                end

                stderr_task = Async do
                  buffer = "" #: String
                  stderr.each_line do |line|
                    buffer += line
                    begin
                      stderr_handler&.call(line)
                    rescue => e
                      # Handler exception shouldn't break command execution
                      Roast::Helpers::Logger.debug("stderr_handler raised: #{e.class} - #{e.message}")
                    end
                  end
                  buffer
                rescue IOError
                  # Stream closed, normal
                  buffer
                end

                [stdout_task.wait, stderr_task.wait]
              end.wait

              [stdout_content, stderr_content, wait_thread.value]
            end
          end

          if timeout
            Timeout.timeout(timeout, &execute_block)
          else
            execute_block.call
          end #: as [String, String, Process::Status]
        rescue Timeout::Error
          kill_process(pid) if pid
          raise TimeoutError, "Command timed out after #{timeout} seconds"
        end

        private

        # Kill a process gracefully with TERM, then KILL if needed
        #: (Integer) -> void
        def kill_process(pid)
          return unless process_running?(pid)

          # Try TERM first
          Process.kill("TERM", pid)
          sleep(0.1)

          # Force KILL if still running
          Process.kill("KILL", pid) if process_running?(pid)
        rescue Errno::ESRCH
          # Process already terminated
        rescue Errno::EPERM
          # Permission denied - process may be owned by different user
          Roast::Helpers::Logger.debug("Could not kill process #{pid}: Permission denied")
        end

        # Check if a process is running
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
