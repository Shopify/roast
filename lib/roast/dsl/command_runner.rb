# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Execute shell commands in Roast.
    #
    # - execute(String) - Shell commands with pipes, redirects, variables
    # - simple_execute(*args) - Direct execution without shell (safer)
    class CommandRunner
      class CommandRunnerError < StandardError; end

      class NoCommandProvidedError < CommandRunnerError; end

      class TimeoutError < CommandRunnerError; end

      @child_processes = {} #: Hash[Integer, { command: String, pgid: Integer? }]
      @child_processes_mutex = Mutex.new

      class << self
        # Execute a shell command (wraps with sh -c)
        #: (String, ?working_directory: (Pathname | String)?, ?timeout: (Integer | Float)?, ?stdout_handler: untyped, ?stderr_handler: untyped) -> [String, String, Process::Status]
        def execute(command, working_directory: nil, timeout: nil, stdout_handler: nil, stderr_handler: nil)
          simple_execute("sh", "-c", command, working_directory: working_directory, timeout: timeout, stdout_handler: stdout_handler, stderr_handler: stderr_handler)
        end

        # Execute a command directly (no shell, safer for untrusted input)
        #: (
        #|  *String,
        #|  ?working_directory: (Pathname | String)?,
        #|  ?timeout: (Integer | Float)?,
        #|  ?stdin_content: String?,
        #|  ?stdout_handler: (^(String) -> void)?,
        #|  ?stderr_handler: (^(String) -> void)?,
        #| ) -> [String, String, Process::Status]
        def simple_execute(
          *args,
          working_directory: nil,
          timeout: nil,
          stdin_content: nil,
          stdout_handler: nil,
          stderr_handler: nil
        )
          args.compact!
          raise NoCommandProvidedError if args.blank?

          stdin, stdout, stderr, wait_thread = Open3 #: as untyped
            .popen3(
              { "PWD" => working_directory&.to_s }.compact,
              *args,
              { chdir: working_directory }.compact,
            )
          stdin.puts stdin_content if stdin_content.present?
          stdin.close
          pid = wait_thread.pid

          timeout_thread = if timeout
            Thread.new do
              sleep(timeout)
              kill_process(pid) if pid
            end
          end

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

          status = wait_thread.value
          timeout_thread&.kill

          if timeout && status.signaled? && (status.termsig == 15 || status.termsig == 9)
            raise TimeoutError, "Command timed out after #{timeout} seconds"
          end

          [stdout_content, stderr_content, status]
        ensure
          begin
            [stdout, stderr].compact.each(&:close)
          rescue
            nil
          end
          if pid && wait_thread&.alive?
            kill_process(pid)
            wait_thread.join(1)
          end
        end

        private

        #: (Integer, String, ?Integer?) -> void
        def track_child_process(pid, command, pgid = nil)
          @child_processes_mutex.synchronize do
            @child_processes[pid] = { command: command, pgid: pgid }
          end
        end

        #: (Integer) -> void
        def untrack_child_process(pid)
          @child_processes_mutex.synchronize do
            @child_processes.delete(pid)
          end
        end

        #: -> Hash[Integer, { command: String, pgid: Integer? }]
        def all_child_processes
          @child_processes_mutex.synchronize { @child_processes.dup }
        end

        #: -> void
        def cleanup_all_children
          Thread.new do
            child_processes = all_child_processes
            Thread.current.exit if child_processes.empty?

            child_processes.each do |pid, info|
              Roast::Helpers::Logger.debug("Cleaning up PID #{pid}: #{info[:command]}")
              kill_process_group(pid, info[:pgid])
            end
          end.join
        end

        #: (Integer, ?Integer?) -> void
        def kill_process_group(pid, pgid = nil)
          untrack_child_process(pid)

          if pgid
            kill_pgid(pgid)
          else
            kill_pid(pid)
          end
        end

        #: (Integer) -> void
        def kill_process(pid)
          kill_pid(pid)
        end

        #: (Integer) -> void
        def kill_pgid(pgid)
          return unless pgid_running?(pgid)

          Process.kill("-TERM", pgid)
          sleep(0.1)
          Process.kill("-KILL", pgid) if pgid_running?(pgid)
        rescue Errno::ESRCH
        rescue Errno::EPERM
          Roast::Helpers::Logger.debug("Could not kill process group #{pgid}: Permission denied")
        end

        #: (Integer) -> void
        def kill_pid(pid)
          return unless process_running?(pid)

          Process.kill("TERM", pid)
          sleep(0.1)
          Process.kill("KILL", pid) if process_running?(pid)

          begin
            Process.kill("-KILL", pid)
          rescue
            nil
          end
        rescue Errno::ESRCH
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

        #: (Integer) -> bool
        def pgid_running?(pgid)
          Process.getpgid(pgid)
          true
        rescue Errno::ESRCH
          false
        end

        #: (T::Array[untyped]) -> String
        def presentable_command(args)
          args.join(" ")
        end
      end
    end
  end
end
