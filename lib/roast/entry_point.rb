# typed: true
# frozen_string_literal: true

require "roast/command"
require "roast/commands"
require "roast/resolver"

module Roast
  module EntryPoint
    extend self
    include Kernel

    def call(args)
      # Handle general help requests (no command specified)
      if args.empty? || (args.length == 1 && (args[0] == "-h" || args[0] == "--help"))
        show_help
        return
      end

      # Resolve the command
      command, command_name, remaining_args = Resolver.call(args)

      if command.nil?
        $stderr.puts "Unknown command: #{command_name}"
        $stderr.puts "Run 'roast --help' for usage information"
        exit(1)
      end

      # Execute the command
      log_file = File.expand_path("~/.roast/logs/roast.log")
      begin
        FileUtils.mkdir_p(File.dirname(log_file))
      rescue
        nil
      end
      executor = CLI::Kit::Executor.new(log_file: log_file)
      executor.call(command, command_name, remaining_args)
    rescue CLI::Kit::Abort => e
      $stderr.puts e.message if e.message && !e.message.empty?
      exit(1)
    rescue StandardError => e
      $stderr.puts "Error: #{e.message}"
      exit(1)
    end

    private

    def show_help
      puts <<~HELP
        🔥🔥🔥 Everyone loves a good roast 🔥🔥🔥

        Roast - A framework for executing structured AI workflows in Ruby

        Usage:
          roast [COMMAND] [OPTIONS] [ARGS...]

        Commands:
          execute [WORKFLOW] [FILES...]   Execute a configured workflow
          resume WORKFLOW                 Resume a paused workflow with an event
          init                           Initialize a new Roast workflow from an example
          list                           List workflows visible to Roast and their source
          validate [WORKFLOW]            Validate a workflow configuration
          sessions                       List stored workflow sessions
          session SESSION_ID             Show details for a specific session
          diagram WORKFLOW_FILE          Generate a visual diagram of a workflow
          version                        Display the current version of Roast

        Global Options:
          -h, --help                     Show this help message
          -v, --verbose                  Show verbose output

        Examples:
          roast execute my_workflow
          roast init --example basic
          roast validate my_workflow.yml
          roast sessions --status running

        For more information about a specific command, use:
          roast [COMMAND] --help
      HELP
    end
  end
end
