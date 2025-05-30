# frozen_string_literal: true

require "English"
require "roast/helpers/logger"

module Roast
  module Tools
    module Cmd
      extend self

      DEFAULT_ALLOWED_COMMANDS = ["pwd", "find", "ls", "rake", "ruby", "dev", "mkdir"].freeze
      CONFIG_ALLOWED_COMMANDS = "allowed_commands"
      private_constant :DEFAULT_ALLOWED_COMMANDS, :CONFIG_ALLOWED_COMMANDS

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
              tool_config = extract_tool_config
              Roast::Tools::Cmd.call(params[:command], tool_config)
            end
          end
        end
      end

      def call(command, config = {})
        Roast::Helpers::Logger.info("🔧 Running command: #{command}\n")

        allowed_commands = config[CONFIG_ALLOWED_COMMANDS] || DEFAULT_ALLOWED_COMMANDS
        validation_result = validate_command(command, allowed_commands)
        return validation_result unless validation_result.nil?

        command_prefix = command.split(" ").first
        execute_command(command, command_prefix)
      rescue StandardError => e
        handle_error(e)
      end

      private

      def validate_command(command, allowed_commands)
        command_prefix = command.split(" ").first
        return if allowed_commands.include?(command_prefix)

        "Error: Command not allowed. Only commands starting with #{allowed_commands.join(", ")} are permitted."
      end

      def extract_tool_config
        return {} unless respond_to?(:configuration)

        configuration&.tool_config("Roast::Tools::Cmd") || {}
      end

      def execute_command(command, command_prefix)
        result = if command_prefix == "dev"
          # Use bash -l -c to ensure we get a login shell with all environment variables
          full_command = "bash -l -c '#{command.gsub("'", "\\'")}'"
          IO.popen(full_command, chdir: Dir.pwd, &:read)
        else
          IO.popen(command, chdir: Dir.pwd, &:read)
        end

        format_output(command, result, $CHILD_STATUS.exitstatus)
      end

      def format_output(command, result, exit_status)
        "Command: #{command}\n" \
          "Exit status: #{exit_status}\n" \
          "Output:\n#{result}"
      end

      def handle_error(error)
        error_message = "Error running command: #{error.message}"
        Roast::Helpers::Logger.error("#{error_message}\n")
        Roast::Helpers::Logger.debug("#{error.backtrace.join("\n")}\n") if ENV["DEBUG"]
        error_message
      end
    end
  end
end
