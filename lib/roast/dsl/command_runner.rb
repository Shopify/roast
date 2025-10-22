# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Simple command runner for DSL cogs
    #
    # Provides command execution with:
    # - Separate stdout/stderr capture
    # - Line-by-line callbacks for custom handling
    # - Timeout support
    # - Process tracking and cleanup
    class CommandRunner
      class TimeoutError < StandardError; end

      @child_processes = {}
      @child_processes_mutex = Mutex.new

      class << self
        # Execute a command with optional stream handlers
        #
        # @param command [String] Command to execute
        # @param args [Array<String>] Command arguments (default: [])
        # @param timeout [Integer] Timeout in seconds (default: 30)
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
        #: (*untyped, ?timeout: Integer, ?stdout_handler: untyped, ?stderr_handler: untyped) -> [String, String, Process::Status]
        def execute(*args, timeout: 30, stdout_handler: nil, stderr_handler: nil)
          args = args #: as untyped
          stdout_content = "" #: String
          stderr_content = "" #: String
          pid = nil #: Integer?

          result = Timeout.timeout(timeout) do
            # rubocop:disable Roast/UseCmdRunner
            Open3.popen3(*args) do |stdin, stdout, stderr, wait_thread|
              # rubocop:enable Roast/UseCmdRunner
              stdin.close
              pid = wait_thread.pid
              track_child_process(pid, presentable_command(args))

              # Read stdout in thread
              stdout_thread = Thread.new do
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

              # Read stderr in thread
              stderr_thread = Thread.new do
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

              stdout_content = stdout_thread.value #: as String
              stderr_content = stderr_thread.value #: as String

              [stdout_content, stderr_content, wait_thread.value]
            end
          end #: as [String, String, Process::Status]

          untrack_child_process(pid) if pid
          result
        rescue Timeout::Error
          cleanup_child_process(pid) if pid
          raise TimeoutError, "Command timed out after #{timeout} seconds"
        end

        # Cleanup all tracked child processes
        #
        # This is called on shutdown/signal handling to ensure no orphaned processes
        #: -> void
        def cleanup_all_children
          Thread.new do # Thread to avoid issues with calling a mutex in a signal handler
            child_processes = all_child_processes
            Thread.current.exit if child_processes.empty?

            child_processes.each do |pid, info|
              Roast::Helpers::Logger.debug("Cleaning up PID #{pid}: #{info[:command]}")
              cleanup_child_process(pid)
            end
          end.join
        end

        private

        # Track a child process
        #: (Integer, String) -> void
        def track_child_process(pid, command)
          @child_processes_mutex.synchronize do
            @child_processes[pid] = { command: command }
          end
        end

        # Untrack a child process
        #: (Integer) -> void
        def untrack_child_process(pid)
          @child_processes_mutex.synchronize { @child_processes.delete(pid) }
        end

        # Get all tracked child processes
        #: -> Hash[Integer, { command: String }]
        def all_child_processes
          @child_processes_mutex.synchronize { @child_processes.dup }
        end

        # Cleanup a running process gracefully
        #
        # Attempts TERM signal first, then escalates to KILL if necessary
        #: (Integer) -> void
        def cleanup_child_process(pid)
          untrack_child_process(pid)

          return unless process_running?(pid)

          # Try TERM first with graduated wait times
          [0.1, 0.2, 0.5].each do |sleep_time|
            Process.kill("TERM", pid)
            break unless process_running?(pid)

            sleep(sleep_time) # Grace period to let the process terminate
          end

          # Force KILL if still running
          Process.kill("KILL", pid) if process_running?(pid)
        rescue Errno::ESRCH
          # Process already terminated, which is fine
        rescue Errno::EPERM
          # Permission denied - process may be owned by different user
          Roast::Helpers::Logger.debug("Could not kill process #{pid}: Permission denied")
        rescue => e
          # Catch any other unexpected errors during cleanup
          Roast::Helpers::Logger.debug("Unexpected error during process cleanup: #{e.message}")
        end

        #: (Integer) -> bool
        def process_running?(pid)
          Process.getpgid(pid)
          true
        rescue Errno::ESRCH
          false
        end

        # Format command and args into presentable string
        #: (Array[untyped]) -> String
        def presentable_command(args)
          args.flatten.map(&:to_s).join(" ")
        end
      end
    end
  end
end
