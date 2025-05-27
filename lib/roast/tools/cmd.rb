# frozen_string_literal: true

require "English"
require "roast/helpers/logger"

module Roast
  module Tools
    module Cmd
      extend self

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :cmd,
              'Run a command in the current working directory (e.g. "ls", "rake", "ruby"). ' \
                "You may use this tool to execute tests and verify if they pass.",
              command: { type: "string", description: "The command to run in a bash shell." },
            ) do |params|
              Roast::Tools::Cmd.call(params[:command])
            end
          end
        end
      end

      def call(command)
        Roast::Helpers::Logger.info("🔧 Running command: #{command}\n")

        # Validate the command starts with one of the allowed prefixes
        allowed_prefixes = ["pwd", "find", "ls", "rake", "ruby", "dev"]
        command_prefix = command.split(" ").first

        err = "Error: Command not allowed. Only commands starting with #{allowed_prefixes.join(", ")} are permitted."
        return err unless allowed_prefixes.any? do |prefix|
          command_prefix == prefix
        end

        # Execute the command in the current working directory
        result = ""

        # Use a full shell environment for commands, especially for 'dev'
        if command_prefix == "dev"
          # Use bash -l -c to ensure we get a login shell with all environment variables
          full_command = "bash -l -c '#{command.gsub("'", "\\'")}'"
          IO.popen(full_command, chdir: Dir.pwd) do |io|
            result = io.read
          end
        else
          # For other commands, use the original approach
          IO.popen(command, chdir: Dir.pwd) do |io|
            result = io.read
          end
        end

        exit_status = $CHILD_STATUS.exitstatus

        # Return the command output along with exit status information
        output = "Command: #{command}\n"
        output += "Exit status: #{exit_status}\n"
        output += "Output:\n#{result}"

        output
      rescue StandardError => e
        "Error running command: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end
    end
  end
end
