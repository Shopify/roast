# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Session < Command
      def invoke(args, _name)
        session_id = args.first
        handle_error(StandardError.new("Session ID is required")) if session_id.nil?

        repository = Workflow::StateRepositoryFactory.create

        unless repository.respond_to?(:get_session_details)
          handle_error(StandardError.new("Session details are only available with SQLite storage. Set ROAST_STATE_STORAGE=sqlite"))
        end

        details = repository.get_session_details(session_id)

        unless details
          handle_error(StandardError.new("Session not found: #{session_id}"))
        end

        session = details[:session]
        states = details[:states]
        events = details[:events]

        puts "Session: #{session[0]}"
        puts "Workflow: #{session[1]}"
        puts "Path: #{session[2]}"
        puts "Status: #{session[3]}"
        puts "Created: #{session[6]}"
        puts "Updated: #{session[7]}"

        if session[5]
          puts
          puts "Final output:"
          puts session[5]
        end

        if states && !states.empty?
          puts
          puts "Steps executed:"
          states.each do |step_index, step_name, created_at|
            puts "  #{step_index}: #{step_name} (#{created_at})"
          end
        end

        if events && !events.empty?
          puts
          puts "Events:"
          events.each do |event_name, event_data, received_at|
            puts "  #{event_name} at #{received_at}"
            puts "    Data: #{event_data}" if event_data
          end
        end
      end

      def help_message
        <<~HELP
          Show details for a specific session

            Usage: roast session SESSION_ID
        HELP
      end
    end
  end
end
