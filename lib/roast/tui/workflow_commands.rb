# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class WorkflowCommands
      attr_reader :workflow_creator, :workflow_executor, :workflow_manager

      def initialize
        @workflow_creator = WorkflowCreator.new
        @workflow_executor = WorkflowExecutor.new
        @workflow_manager = WorkflowManager.new
      end

      # Register workflow commands with the command registry
      class << self
        def register(registry)
          instance = new

          # Workflow creation commands
          registry.register(
            name: "/workflow-create",
            aliases: ["/wf-create", "/wfc"],
            description: "Create a new workflow from natural language description",
            handler: instance.method(:handle_workflow_create),
          )

          registry.register(
            name: "/workflow-suggest",
            aliases: ["/wf-suggest", "/wfs"],
            description: "Get workflow suggestions based on current directory",
            handler: instance.method(:handle_workflow_suggest),
          )

          registry.register(
            name: "/workflow-template",
            aliases: ["/wf-template", "/wft"],
            description: "Create workflow from template",
            handler: instance.method(:handle_workflow_template),
          )

          # Workflow execution commands
          registry.register(
            name: "/workflow-run",
            aliases: ["/wf-run", "/wfr", "/run"],
            description: "Execute a workflow file",
            handler: instance.method(:handle_workflow_run),
          )

          registry.register(
            name: "/workflow-debug",
            aliases: ["/wf-debug", "/wfd"],
            description: "Execute workflow interactively with debugging",
            handler: instance.method(:handle_workflow_debug),
          )

          registry.register(
            name: "/workflow-stream",
            aliases: ["/wf-stream", "/wfst"],
            description: "Stream workflow output in real-time",
            handler: instance.method(:handle_workflow_stream),
          )

          # Workflow management commands
          registry.register(
            name: "/workflow-list",
            aliases: ["/wf-list", "/wfl", "/workflows"],
            description: "List available workflows",
            handler: instance.method(:handle_workflow_list),
          )

          registry.register(
            name: "/workflow-show",
            aliases: ["/wf-show", "/wfsh"],
            description: "Show details of a workflow",
            handler: instance.method(:handle_workflow_show),
          )

          registry.register(
            name: "/workflow-edit",
            aliases: ["/wf-edit", "/wfe"],
            description: "Edit a workflow file",
            handler: instance.method(:handle_workflow_edit),
          )

          registry.register(
            name: "/workflow-stats",
            aliases: ["/wf-stats", "/wfst"],
            description: "Show execution statistics for a workflow",
            handler: instance.method(:handle_workflow_stats),
          )

          registry.register(
            name: "/workflow-reload",
            aliases: ["/wf-reload", "/wfrl"],
            description: "Reload a workflow in the current session",
            handler: instance.method(:handle_workflow_reload),
          )
        end
      end

      # Command handlers

      def handle_workflow_create(args, context = {})
        description = if args.empty?
          ::CLI::UI.ask("Describe the workflow you want to create:")
        else
          args.join(" ")
        end

        return unless description && !description.strip.empty?

        interactive = ::CLI::UI.confirm("Would you like to refine the workflow interactively?")

        workflow_path = @workflow_creator.create_from_description(
          description,
          interactive: interactive,
        )

        if workflow_path && ::CLI::UI.confirm("Run the workflow now?")
          handle_workflow_run([workflow_path], context)
        end
      end

      def handle_workflow_suggest(args, context = {})
        directory = args.first || "."

        suggestions = @workflow_creator.suggest_workflows(directory)

        if suggestions.any? && ::CLI::UI.confirm("Create a workflow from a suggestion?")
          choice = ::CLI::UI::Prompt.ask("Select a suggestion:") do |handler|
            suggestions.each do |suggestion|
              handler.option(suggestion[:name]) { suggestion }
            end
            handler.option("Cancel") { nil }
          end

          if choice
            description = "Create a #{choice[:name]} workflow that #{choice[:description].downcase}"
            workflow_path = @workflow_creator.create_from_description(description)

            if workflow_path && ::CLI::UI.confirm("Run the workflow now?")
              handle_workflow_run([workflow_path], context)
            end
          end
        end
      end

      def handle_workflow_template(args, context = {})
        template_name = args.first

        workflow_path = @workflow_manager.create_from_template(template_name)

        if workflow_path && ::CLI::UI.confirm("Run the workflow now?")
          handle_workflow_run([workflow_path], context)
        end
      end

      def handle_workflow_run(args, context = {})
        if args.empty?
          # Show list and let user select
          workflows = @workflow_manager.list_workflows(recursive: false)

          if workflows.empty?
            puts ::CLI::UI.fmt("{{yellow:No workflows found. Use /workflow-create to create one.}}")
            return
          end

          workflow_path = ::CLI::UI::Prompt.ask("Select a workflow to run:") do |handler|
            workflows.each do |workflow|
              label = workflow[:name]
              label += " (#{workflow[:description]})" if workflow[:description]
              handler.option(label) { workflow[:path] }
            end
            handler.option("Cancel") { nil }
          end

          return unless workflow_path
        else
          workflow_path = args.first
        end

        # Check for additional arguments (files to process)
        files = args[1..-1] || []

        # Parse options from context or args
        options = parse_workflow_options(args, context)

        # Execute the workflow
        success = @workflow_executor.execute(workflow_path, files, options)

        # Track execution
        start_time = Time.now
        @workflow_manager.track_execution(
          workflow_path,
          success: success,
          duration: Time.now - start_time,
        )
      end

      def handle_workflow_debug(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        files = args[1..-1] || []
        options = parse_workflow_options(args, context)

        @workflow_executor.execute_interactive(workflow_path, files, options)
      end

      def handle_workflow_stream(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        files = args[1..-1] || []
        options = parse_workflow_options(args, context)

        @workflow_executor.stream_output(workflow_path, files, options)
      end

      def handle_workflow_list(args, context = {})
        recursive = !args.include?("--local")
        @workflow_manager.list_workflows(recursive: recursive)
      end

      def handle_workflow_show(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        @workflow_manager.show_workflow(workflow_path)

        if ::CLI::UI.confirm("Would you like to run this workflow?")
          handle_workflow_run([workflow_path], context)
        end
      end

      def handle_workflow_edit(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        if @workflow_manager.edit_workflow(workflow_path)
          if ::CLI::UI.confirm("Run the edited workflow?")
            handle_workflow_run([workflow_path], context)
          end
        end
      end

      def handle_workflow_stats(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        stats = @workflow_manager.get_statistics(workflow_path)

        if stats
          ::CLI::UI::Frame.open("Workflow Statistics") do
            puts ::CLI::UI.fmt("{{bold:Total Runs:}} #{stats[:total_runs]}")
            puts ::CLI::UI.fmt("{{bold:Successful:}} {{green:#{stats[:successful]}}}")
            puts ::CLI::UI.fmt("{{bold:Failed:}} {{red:#{stats[:failed]}}}")
            puts ::CLI::UI.fmt("{{bold:Success Rate:}} #{stats[:success_rate]}%")

            if stats[:average_duration]
              puts ::CLI::UI.fmt("{{bold:Average Duration:}} #{format_duration(stats[:average_duration])}")
            end

            if stats[:last_run]
              puts ::CLI::UI.fmt("{{bold:Last Run:}} #{format_time_relative(stats[:last_run])}")
            end

            if stats[:last_success]
              puts ::CLI::UI.fmt("{{bold:Last Success:}} #{format_time_relative(stats[:last_success])}")
            end
          end
        else
          puts ::CLI::UI.fmt("{{gray:No execution history for this workflow}}")
        end
      end

      def handle_workflow_reload(args, context = {})
        workflow_path = args.first || select_workflow
        return unless workflow_path

        @workflow_manager.reload_workflow(workflow_path)
      end

      private

      def select_workflow
        workflows = @workflow_manager.list_workflows(recursive: false)

        return if workflows.empty?

        ::CLI::UI::Prompt.ask("Select a workflow:") do |handler|
          workflows.each do |workflow|
            label = workflow[:name]
            label += " - #{workflow[:description]}" if workflow[:description]
            handler.option(label) { workflow[:path] }
          end
          handler.option("Cancel") { nil }
        end
      end

      def parse_workflow_options(args, context)
        options = {}

        # Parse command-line style options
        args.each do |arg|
          case arg
          when "--verbose", "-v"
            options[:verbose] = true
          when "--concise", "-c"
            options[:concise] = true
          when /^--output=(.+)/, /^-o=(.+)/
            options[:output] = ::Regexp.last_match(1)
          when /^--replay=(.+)/
            options[:replay] = ::Regexp.last_match(1)
          when /^--pause=(.+)/
            options[:pause] = ::Regexp.last_match(1)
          when "--file-storage"
            options[:file_storage] = true
          end
        end

        # Merge with context options if provided
        options.merge!(context[:options]) if context[:options]

        options
      end

      def format_duration(seconds)
        if seconds < 60
          "#{seconds.round(1)}s"
        elsif seconds < 3600
          minutes = (seconds / 60).floor
          secs = (seconds % 60).round
          "#{minutes}m #{secs}s"
        else
          hours = (seconds / 3600).floor
          minutes = ((seconds % 3600) / 60).floor
          "#{hours}h #{minutes}m"
        end
      end

      def format_time_relative(timestamp_str)
        timestamp = Time.parse(timestamp_str)
        diff = Time.now - timestamp

        case diff
        when 0..59
          "#{diff.round}s ago"
        when 60..3599
          "#{(diff / 60).round}m ago"
        when 3600..86399
          "#{(diff / 3600).round}h ago"
        when 86400..604799
          "#{(diff / 86400).round}d ago"
        else
          timestamp.strftime("%Y-%m-%d")
        end
      end
    end
  end
end
