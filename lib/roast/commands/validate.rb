# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Validate < Command
      def invoke(args, name)
        workflow_path = args.first
        options = parse_options(args[1..], name)

        validation_command = Roast::Workflow::ValidationCommand.new(options)
        validation_command.execute(workflow_path)
      end

      def help_message
        <<~HELP
          Validate a workflow configuration
          Usage: roast validate [WORKFLOW_CONFIGURATION_FILE]
          Options:
            -s, --strict               Treat warnings as errors
        HELP
      end

      def configure_options(command_name, parser, options)
        parser.on("-s", "--strict") { options[:strict] = true }
      end
    end
  end
end
