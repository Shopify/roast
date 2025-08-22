# typed: true
# frozen_string_literal: true

module Roast
  module Helpers
    class CmdRunner
      DEFAULT_TIMEOUT = 30
      MAX_TIMEOUT = 3600 # 1 hour

      @child_processes = {}
      @child_processes_mutex = Mutex.new

      class << self
        #: (*untyped, **untyped) -> [String, Process::Status]
        def capture2(*args, **options)
          args = args #: as untyped
          stdout, _stderr, status = capture3(*args, **options)
          [stdout, status]
        end

        #: (*untyped, **untyped) -> [String, Process::Status]
        def capture2e(*args, **options)
          args = args #: as untyped
          stdout, stderr, status = capture3(*args, **options)
          combined_output = stdout + stderr
          [combined_output, status]
        end

        #: (*untyped, **untyped) -> [String?, String?, Process::Status?]
        def capture3(*args, **options)
          args = args #: as untyped
          popen3(*args, **options) do |stdin, stdout, stderr, wait_thr|
            stdin.close # Prevent hanging on stdin-waiting commands

            stdout_thread = threaded_read(stdout)
            stderr_thread = threaded_read(stderr)

            [stdout_thread.value, stderr_thread.value, wait_thr.value]
          end
        end

        #: (*untyped, **untyped) -> bool
        def system(*args, **options)
          args = args #: as untyped
          popen3(*args, **options) do |stdin, stdout, stderr, wait_thr|
            stdin.close # Prevent hanging on stdin-waiting commands

            stdout_thread = threaded_stream(from: stdout, to: $stdout)
            stderr_thread = threaded_stream(from: stderr, to: $stderr)

            stdout_thread.join
            stderr_thread.join

            wait_thr.value.success?
          end
        end

        #: (*untyped, **untyped) ?{ (IO, IO, IO, Thread) -> untyped } -> [IO, IO, IO, Thread] | untyped
        def popen3(*args, **options, &block)
          args = args #: as untyped

          timeout = options.delete(:timeout)
          validate_timeout(timeout) unless timeout.nil?

          raise ArgumentError, "Timeout provided but no block given" if !timeout.nil? && !block_given?

          # Mirror Open3.popen3 behavior - if no block, return the IO objects and thread
          unless block_given?
            stdin, stdout, stderr, wait_thr = Open3.popen3(*args, **options)
            track_child_process(wait_thr.pid, presentable_command(args))
            return [stdin, stdout, stderr, wait_thr]
          end

          Open3.popen3(*args, **options) do |stdin, stdout, stderr, wait_thr|
            track_child_process(wait_thr.pid, presentable_command(args))

            runnable = proc { yield(stdin, stdout, stderr, wait_thr) } #: Proc
            timeout.nil? ? runnable.call : Timeout.timeout(timeout, &runnable)
          rescue Timeout::Error => e
            raise e.class, "Command '#{presentable_command(args)}' timed out after #{timeout} seconds: #{e.message}"
          ensure
            cleanup_child_process(wait_thr.pid) unless wait_thr.nil?
          end
        end

        #: -> void
        def cleanup_all_children
          Thread.new do # Thread to avoid issues with calling a mutex in a signal handler
            child_processes = all_child_processes
            Thread.current.exit if child_processes.empty?

            child_processes.each do |pid, info|
              Roast::Helpers::Logger.info("Cleaning up PID #{pid}: #{info[:command]}")
              cleanup_child_process(pid)
            end
          end.join
        end

        #: (Integer?) -> Integer
        def normalize_timeout(timeout)
          return DEFAULT_TIMEOUT if timeout.nil? || timeout <= 0

          [timeout, MAX_TIMEOUT].min
        end

        private

        #: (Integer) -> void
        def validate_timeout(timeout)
          if timeout <= 0 || timeout > MAX_TIMEOUT
            raise ArgumentError, "Invalid timeout value: #{timeout.inspect}"
          end
        end

        #: (Array) -> String
        def presentable_command(args)
          args.flatten.map(&:to_s).join(" ")
        end

        #: (IO) -> Thread
        def threaded_read(stream)
          Thread.new do
            buffer = ""
            stream.each_line do |line|
              buffer += line
            end
            buffer
          rescue IOError => e
            Roast::Helpers::Logger.debug("IOError: #{e.message}")
          end
        end

        #: (from: IO, to: IO) -> Thread
        def threaded_stream(from:, to:)
          Thread.new do
            from.each_line do |line|
              to.puts(line)
            end
          rescue IOError => e
            Roast::Helpers::Logger.debug("IOError: #{e.message}")
          end
        end

        #: (Integer, String) -> void
        def track_child_process(pid, command)
          @child_processes_mutex.synchronize do
            @child_processes[pid] = {
              command: command,
              started_at: Time.now,
            }
          end
        end

        #: (Integer) -> void
        def untrack_child_process(pid)
          @child_processes_mutex.synchronize { @child_processes.delete(pid) }
        end

        #: -> Hash[Integer, { command: String, started_at: Time }]
        def all_child_processes
          @child_processes_mutex.synchronize { @child_processes.dup }
        end

        #: (Integer) -> void
        def cleanup_child_process(pid)
          untrack_child_process(pid)

          return unless process_running?(pid)

          [0.1, 0.2, 0.5].each do |sleep_time|
            Process.kill("TERM", pid)
            break unless process_running?(pid)

            sleep(sleep_time) # Grace period to let the process terminate
          end

          # Force kill if still alive
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
      end
    end
  end
end
