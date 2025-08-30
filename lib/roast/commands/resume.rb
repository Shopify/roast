# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Resume < Command
      def invoke(args, name)
        workflow_path = args.first
        handle_error(StandardError.new("Workflow file is required")) if workflow_path.nil?

        options = parse_options(args[1..], name)

        handle_error(StandardError.new("Event name is required (use --event)")) unless options[:event]

        expanded_workflow_path = if workflow_path.include?("workflow.yml")
          File.expand_path(workflow_path)
        else
          File.expand_path("roast/#{workflow_path}/workflow.yml")
        end

        unless File.exist?(expanded_workflow_path)
          handle_error(StandardError.new("Workflow file not found: #{expanded_workflow_path}"))
        end

        # Store the event in the session
        repository = Workflow::StateRepositoryFactory.create

        unless repository.respond_to?(:add_event)
          handle_error(StandardError.new("Event resumption requires SQLite storage. Set ROAST_STATE_STORAGE=sqlite"))
        end

        # Parse event data if provided
        event_data = options[:event_data] ? JSON.parse(options[:event_data]) : nil

        # Add the event to the session
        session_id = options[:session_id]
        repository.add_event(expanded_workflow_path, session_id, options[:event], event_data)

        # Resume workflow execution from the wait state
        resume_options = options.transform_keys(&:to_sym).merge(
          resume_from_event: options[:event],
          session_id: session_id,
        )

        Roast::Workflow::WorkflowRunner.new(expanded_workflow_path, [], resume_options).begin!
      end

      def help_message
        <<~HELP
          Resume a paused workflow with an event

          Usage: roast resume WORKFLOW_FILE

          Options:
            -e, --event EVENT          Event name to trigger (required)
            -s, --session-id ID        Specific session ID to resume (defaults to most recent)
            --event-data JSON          JSON data to pass with the event
        HELP
      end

      def configure_options(command_name, parser, options)
        parser.on("-e", "--event EVENT") { |event| options[:event] = event }
        parser.on("-s", "--session-id ID") { |id| options[:session_id] = id }
        parser.on("--event-data JSON") { |data| options[:event_data] = data }
      end
    end
  end
end
