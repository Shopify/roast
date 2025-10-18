# typed: false
# frozen_string_literal: true

require "English"
require "roast/helpers/logger"

module Roast
  module Tools
    module Cmd
      extend self

      DEFAULT_ALLOWED_COMMANDS = [
        { "name" => "pwd", "description" => "pwd command - print current working directory path" },
        { "name" => "find", "description" => "find command - search for files/directories using patterns like -name '*.rb'" },
        { "name" => "ls", "description" => "ls command - list directory contents with options like -la, -R" },
        { "name" => "rake", "description" => "rake command - run Ruby tasks defined in Rakefile" },
        { "name" => "ruby", "description" => "ruby command - execute Ruby code or scripts, supports -e for inline code" },
        { "name" => "dev", "description" => "Shopify dev CLI - development environment tool with subcommands" },
        { "name" => "mkdir", "description" => "mkdir command - create directories, supports -p for parent directories" },
      ].freeze

      CONFIG_ALLOWED_COMMANDS = "allowed_commands"
      private_constant :DEFAULT_ALLOWED_COMMANDS, :CONFIG_ALLOWED_COMMANDS

      class << self
        # Add this method to be included in other classes
        def included(base)
          @base_class = base
        end

        # Called after configuration is loaded
        def post_configuration_setup(base, config = {})
          allowed_commands = config[CONFIG_ALLOWED_COMMANDS] || DEFAULT_ALLOWED_COMMANDS

          allowed_commands.each do |command_entry|
            case command_entry
            when String
              register_command_function(base, command_entry, nil)
            when Hash
              command_name = command_entry["name"] || command_entry[:name]
              description = command_entry["description"] || command_entry[:description]

              if command_name.nil?
                raise ArgumentError, "Command configuration must include 'name' field"
              end

              register_command_function(base, command_name, description)
            else
              raise ArgumentError, "Invalid command configuration format: #{command_entry.inspect}"
            end
          end
        end

        private

        def register_command_function(base, command, custom_description = nil)
          function_name = command.to_sym
          description = custom_description || generate_command_description(command)

          base.class_eval do
            function(
              function_name,
              description,
              args: {
                type: "string",
                description: "Arguments to pass to the #{command} command",
                required: false,
              },
              timeout: {
                type: "integer",
                description: "Timeout in seconds (optional, default: 30)",
                required: false,
              },
            ) do |params|
              full_command = if params[:args].nil? || params[:args].empty?
                command
              else
                "#{command} #{params[:args]}"
              end

              Roast::Tools::Cmd.execute_allowed_command(full_command, command, params[:timeout])
            end
          end
        end

        def generate_command_description(command)
          default_cmd = DEFAULT_ALLOWED_COMMANDS.find { |cmd| cmd["name"] == command }
          default_cmd ? default_cmd["description"] : "Execute the #{command} command"
        end
      end

      def execute_allowed_command(full_command, command_prefix, timeout = 30)
        Roast::Helpers::Logger.info("🔧 Running command: #{full_command}\n")

        execute_command(full_command, command_prefix, timeout)
      rescue Roast::Error => e
        handle_error(e)
      end

      # Legacy method for backward compatibility
      def call(command, config = {}, timeout: 30)
        Roast::Helpers::Logger.info("🔧 Running command: #{command}\n")

        allowed_commands = config[CONFIG_ALLOWED_COMMANDS] || DEFAULT_ALLOWED_COMMANDS
        validation_result = validate_command(command, allowed_commands)
        return validation_result unless validation_result.nil?

        command_prefix = command.split(" ").first

        execute_command(command, command_prefix, timeout)
      rescue Roast::Error => e
        handle_error(e)
      end

      private

      def validate_command(command, allowed_commands)
        command_prefix = command.split(" ").first

        # Extract command names from the allowed_commands array
        allowed_command_names = allowed_commands.map do |cmd_entry|
          case cmd_entry
          when String
            cmd_entry
          when Hash
            cmd_entry["name"] || cmd_entry[:name]
          end
        end.compact

        return if allowed_command_names.include?(command_prefix)

        "Error: Command not allowed. Only commands starting with #{allowed_command_names.join(", ")} are permitted."
      end

      def extract_tool_config
        return {} unless respond_to?(:configuration)

        configuration&.tool_config("Roast::Tools::Cmd") || {}
      end

      def execute_command(command, command_prefix, timeout)
        timeout = Roast::Helpers::CmdRunner.normalize_timeout(timeout)

        full_command = if command_prefix == "dev"
          "bash -l -c '#{command.gsub("'", "\\'")}'"
        else
          command
        end

        result, status = Roast::Helpers::CmdRunner.capture2e(
          full_command,
          timeout: timeout,
        )

        format_output(command, result, status.exitstatus)
      rescue Timeout::Error, Errno::ENOENT => e
        error_message = "Error running command: #{e.message}"
        Roast::Helpers::Logger.error(error_message + "\n")
        error_message
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
