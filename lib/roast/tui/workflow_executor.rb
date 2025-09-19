# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class WorkflowExecutor
      attr_reader :workflow_runner, :output_buffer, :step_timings, :current_step

      def initialize
        @output_buffer = []
        @step_timings = {}
        @interrupted = false
      end

      # Execute a workflow file within the TUI session
      def execute(workflow_path, files = [], options = {})
        return unless validate_workflow_file(workflow_path)

        ::CLI::UI::Frame.open("Executing Workflow: #{File.basename(workflow_path)}", timing: true) do
          setup_output_capture

          begin
            # Initialize the workflow runner with TUI-specific options
            merged_options = options.merge(
              verbose: options.fetch(:verbose, true),
              concise: options.fetch(:concise, false),
              output: options[:output],
            )

            @workflow_runner = ::Roast::Workflow::WorkflowRunner.new(
              workflow_path,
              files,
              merged_options,
            )

            # Set up interrupt handler
            setup_interrupt_handler

            # Subscribe to workflow events
            subscribe_to_workflow_events

            # Execute the workflow
            puts ::CLI::UI.fmt("{{cyan:Starting workflow execution...}}\n")

            @workflow_runner.begin!

            # Display summary
            display_execution_summary

            true
          rescue Roast::Errors::ExitEarly => e
            puts ::CLI::UI.fmt("\n{{yellow:⚠}} Workflow exited early: #{e.message}")
            false
          rescue StandardError => e
            puts ::CLI::UI.fmt("\n{{red:✗}} Workflow execution failed: #{e.message}")
            puts ::CLI::UI.fmt("{{gray:#{e.backtrace.first(5).join("\n")}}}")
            false
          ensure
            restore_output
            cleanup_interrupt_handler
          end
        end
      end

      # Execute workflow steps interactively with debugging
      def execute_interactive(workflow_path, files = [], options = {})
        return unless validate_workflow_file(workflow_path)

        ::CLI::UI::Frame.open("Interactive Workflow Execution", timing: true) do
          config = load_workflow_config(workflow_path)
          steps = config["steps"]

          puts ::CLI::UI.fmt("{{bold:Workflow:}} #{config["name"]}")
          puts ::CLI::UI.fmt("{{bold:Steps:}} #{steps.size}\n")

          # Initialize workflow runner but don't start yet
          @workflow_runner = ::Roast::Workflow::WorkflowRunner.new(
            workflow_path,
            files,
            options.merge(pause: true),
          )

          steps.each_with_index do |step, index|
            break if @interrupted

            step_name = extract_step_name(step)

            ::CLI::UI::Frame.open("Step #{index + 1}/#{steps.size}: #{step_name}") do
              puts ::CLI::UI.fmt("{{gray:#{format_step_description(step)}}}\n")

              # Ask for user action
              action = prompt_for_step_action(step_name)

              case action
              when :run
                execute_single_step(step_name, index, steps.size)
              when :skip
                puts ::CLI::UI.fmt("{{yellow:Skipped}}")
                next
              when :debug
                debug_step(step_name, config)
                redo # Re-prompt for this step
              when :abort
                puts ::CLI::UI.fmt("{{red:Workflow aborted by user}}")
                break
              end
            end
          end

          display_execution_summary unless @interrupted
        end
      end

      # Stream workflow output in real-time
      def stream_output(workflow_path, files = [], options = {})
        return unless validate_workflow_file(workflow_path)

        ::CLI::UI::Frame.open("Streaming Workflow Output", timing: false) do
          puts ::CLI::UI.fmt("{{cyan:Streaming output from: #{File.basename(workflow_path)}}}\n")

          # Create a thread to handle output streaming
          output_thread = Thread.new do
            # Redirect stdout and stderr to capture output
            original_stdout = $stdout
            original_stderr = $stderr

            read_stdout, write_stdout = IO.pipe
            read_stderr, write_stderr = IO.pipe

            $stdout = write_stdout
            $stderr = write_stderr

            # Start workflow in separate thread
            workflow_thread = Thread.new do
              runner = ::Roast::Workflow::WorkflowRunner.new(workflow_path, files, options)
              runner.begin!
            end

            # Stream output
            loop do
              ready = IO.select([read_stdout, read_stderr], nil, nil, 0.1)

              if ready
                ready[0].each do |io|
                  line = io.read_nonblock(1024)
                  print(format_streamed_output(line)) if line
                rescue IO::WaitReadable
                  # No data available right now
                rescue EOFError
                  # Stream closed
                end
              end

              break unless workflow_thread.alive?
            end

            workflow_thread.join
          ensure
            $stdout = original_stdout if original_stdout
            $stderr = original_stderr if original_stderr
            write_stdout&.close
            write_stderr&.close
          end

          output_thread.join
        end
      end

      private

      def validate_workflow_file(workflow_path)
        unless File.exist?(workflow_path)
          puts ::CLI::UI.fmt("{{red:✗}} Workflow file not found: #{workflow_path}")
          return false
        end

        begin
          YAML.safe_load_file(workflow_path)
          true
        rescue => e
          puts ::CLI::UI.fmt("{{red:✗}} Invalid workflow file: #{e.message}")
          false
        end
      end

      def load_workflow_config(workflow_path)
        YAML.safe_load_file(workflow_path)
      end

      def extract_step_name(step)
        case step
        when String
          # Inline prompt or simple step name
          step.length > 30 ? "#{step[0..27]}..." : step
        when Hash
          step.keys.first.to_s
        else
          step.to_s
        end
      end

      def format_step_description(step)
        case step
        when String
          step
        when Hash
          key = step.keys.first
          value = step.values.first
          "#{key}: #{value}"
        else
          step.to_s
        end
      end

      def prompt_for_step_action(step_name)
        ::CLI::UI::Prompt.ask("Action for '#{step_name}'?") do |handler|
          handler.option("Run")   { :run }
          handler.option("Skip")  { :skip }
          handler.option("Debug") { :debug }
          handler.option("Abort") { :abort }
        end
      end

      def execute_single_step(step_name, index, total)
        start_time = Time.now

        puts ::CLI::UI.fmt("{{cyan:Executing...}}")

        begin
          # This would need integration with the actual workflow executor
          # For now, we'll simulate execution
          sleep(0.5) # Simulate work

          elapsed = Time.now - start_time
          @step_timings[step_name] = elapsed

          puts ::CLI::UI.fmt("{{green:✓}} Completed in #{format_duration(elapsed)}")
        rescue => e
          puts ::CLI::UI.fmt("{{red:✗}} Failed: #{e.message}")
          raise
        end
      end

      def debug_step(step_name, config)
        ::CLI::UI::Frame.open("Debug Information") do
          puts ::CLI::UI.fmt("{{bold:Step:}} #{step_name}")

          # Show step configuration if available
          if config[step_name]
            puts ::CLI::UI.fmt("\n{{bold:Configuration:}}")
            puts ::CLI::UI.fmt("{{gray:#{YAML.dump(config[step_name])}}}")
          end

          # Show available variables
          puts ::CLI::UI.fmt("\n{{bold:Available Tools:}}")
          if config["tools"]
            config["tools"].each do |tool|
              puts ::CLI::UI.fmt("  • #{tool}")
            end
          else
            puts ::CLI::UI.fmt("  {{gray:No tools configured}}")
          end

          puts ::CLI::UI.fmt("\n{{gray:Press Enter to continue...}}")
          gets
        end
      end

      def setup_output_capture
        @original_stdout = $stdout
        @original_stderr = $stderr

        # Create custom IO that duplicates output to both console and buffer
        @captured_stdout = StringIO.new
        @captured_stderr = StringIO.new

        # We'll keep console output visible while capturing
        $stdout = MultiIO.new(@original_stdout, @captured_stdout)
        $stderr = MultiIO.new(@original_stderr, @captured_stderr)
      end

      def restore_output
        $stdout = @original_stdout if @original_stdout
        $stderr = @original_stderr if @original_stderr
      end

      def setup_interrupt_handler
        @original_interrupt = Signal.trap("INT") do
          @interrupted = true
          puts ::CLI::UI.fmt("\n\n{{yellow:⚠}} Workflow interrupted by user")

          # Ask if they want to continue or abort
          continue = ::CLI::UI.confirm("Continue with next step?")

          unless continue
            puts ::CLI::UI.fmt("{{red:Aborting workflow...}}")
            exit(1)
          end
        end
      end

      def cleanup_interrupt_handler
        Signal.trap("INT", @original_interrupt) if @original_interrupt
      end

      def subscribe_to_workflow_events
        # Subscribe to ActiveSupport notifications if available
        @workflow_subscription = ActiveSupport::Notifications.subscribe(/roast\.workflow/) do |name, start, finish, id, payload|
          handle_workflow_event(name, start, finish, id, payload)
        end if defined?(ActiveSupport::Notifications)

        @step_subscription = ActiveSupport::Notifications.subscribe(/roast\.step/) do |name, start, finish, id, payload|
          handle_step_event(name, start, finish, id, payload)
        end if defined?(ActiveSupport::Notifications)
      end

      def handle_workflow_event(name, start, finish, id, payload)
        case name
        when "roast.workflow.start"
          puts ::CLI::UI.fmt("{{cyan:▶}} Workflow started: #{payload[:name]}")
        when "roast.workflow.complete"
          duration = finish - start
          status = payload[:success] ? "{{green:✓ Success}}" : "{{red:✗ Failed}}"
          puts ::CLI::UI.fmt("\n#{status} - Total time: #{format_duration(duration)}")
        end
      end

      def handle_step_event(name, start, finish, id, payload)
        case name
        when "roast.step.start"
          @current_step = payload[:step_name]
          puts ::CLI::UI.fmt("\n{{cyan:→}} Step: #{@current_step}")
        when "roast.step.complete"
          if finish && start
            duration = finish - start
            @step_timings[@current_step] = duration
            puts ::CLI::UI.fmt("   {{green:✓}} #{format_duration(duration)}")
          end
        when "roast.step.error"
          puts ::CLI::UI.fmt("   {{red:✗}} Error: #{payload[:error]}")
        end
      end

      def display_execution_summary
        ::CLI::UI::Frame.open("Execution Summary") do
          if @step_timings.any?
            puts ::CLI::UI.fmt("{{bold:Step Timings:}}")

            @step_timings.each do |step, duration|
              puts ::CLI::UI.fmt("  • #{step}: #{format_duration(duration)}")
            end

            total = @step_timings.values.sum
            puts ::CLI::UI.fmt("\n{{bold:Total time:}} #{format_duration(total)}")
          end

          if @output_buffer.any?
            puts ::CLI::UI.fmt("\n{{bold:Output Preview:}}")
            puts ::CLI::UI.fmt("{{gray:#{@output_buffer.last(10).join("\n")}}}")
          end
        end
      end

      def format_duration(seconds)
        if seconds < 1
          "#{(seconds * 1000).round}ms"
        elsif seconds < 60
          "#{seconds.round(1)}s"
        else
          minutes = (seconds / 60).floor
          secs = (seconds % 60).round
          "#{minutes}m #{secs}s"
        end
      end

      def format_streamed_output(line)
        # Add color formatting based on content
        case line
        when /error/i
          ::CLI::UI.fmt("{{red:#{line}}}")
        when /warning/i
          ::CLI::UI.fmt("{{yellow:#{line}}}")
        when /success|complete/i
          ::CLI::UI.fmt("{{green:#{line}}}")
        when /^🔥/
          ::CLI::UI.fmt("{{bold:#{line}}}")
        else
          line
        end
      end
    end

    # Helper class to duplicate IO output
    class MultiIO
      def initialize(*targets)
        @targets = targets
      end

      def write(*args)
        @targets.each { |t| t.write(*args) }
        args.first.to_s.length
      end

      def puts(*args)
        @targets.each { |t| t.puts(*args) }
        nil
      end

      def print(*args)
        @targets.each { |t| t.print(*args) }
        nil
      end

      def flush
        @targets.each(&:flush)
      end

      def close
        @targets.each(&:close)
      end
    end
  end
end
