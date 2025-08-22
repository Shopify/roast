# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Sessions < Command
      def invoke(args, name)
        options = parse_options(args, name)
        repository = Workflow::StateRepositoryFactory.create

        unless repository.respond_to?(:list_sessions)
          handle_error(StandardError.new("Session listing is only available with SQLite storage. Set ROAST_STATE_STORAGE=sqlite"))
        end

        if options[:cleanup] && options[:older_than]
          count = repository.cleanup_old_sessions(options[:older_than])
          puts "Cleaned up #{count} old sessions"
          return
        end

        sessions = repository.list_sessions(
          status: options[:status],
          workflow_name: options[:workflow],
          older_than: options[:older_than],
        )

        if sessions.empty?
          puts "No sessions found"
          return
        end

        puts "Found #{sessions.length} session(s):"
        puts

        sessions.each do |session|
          id, workflow_name, _, status, current_step, created_at, updated_at = session

          puts "Session: #{id}"
          puts "  Workflow: #{workflow_name}"
          puts "  Status: #{status}"
          puts "  Current step: #{current_step || "N/A"}"
          puts "  Created: #{created_at}"
          puts "  Updated: #{updated_at}"
          puts
        end
      end

      def help_message
        <<~HELP
          List stored workflow sessions
          Usage: roast sessions
          Options:
            -s, --status STATUS        Filter by status (running, waiting, completed, failed)
            -w, --workflow NAME        Filter by workflow name
            --older-than TIME          Show sessions older than specified time (e.g., '7d', '1h')
            --cleanup                  Clean up old sessions
        HELP
      end

      def configure_options(command_name, parser, options)
        parser.on("-s", "--status STATUS") { |status| options[:status] = status }
        parser.on("-w", "--workflow NAME") { |workflow| options[:workflow] = workflow }
        parser.on("--older-than TIME") { |time| options[:older_than] = time }
        parser.on("--cleanup") { options[:cleanup] = true }
      end
    end
  end
end
