# frozen_string_literal: true

require "English"
require "roast/helpers/logger"
require "roast/helpers/timeout_handler"

module Roast
  module Tools
    module Cmd
      extend self

      # Cmd-specific configuration key
      CONFIG_ALLOWED_COMMANDS = "allowed_commands"

      DEFAULT_ALLOWED_COMMANDS = %w[
        awk
        basename
        bc
        cat
        cd
        chmod
        chown
        cp
        cut
        date
        df
        diff
        dirname
        du
        echo
        env
        expr
        find
        grep
        head
        hostname
        id
        kill
        less
        ln
        ls
        man
        mkdir
        more
        mv
        ps
        pwd
        rm
        rmdir
        sed
        sleep
        sort
        tail
        tar
        tee
        test
        touch
        tr
        uname
        uniq
        wc
        which
        whoami
      ].freeze

      class << self
        def register
          DEFAULT_ALLOWED_COMMANDS.each do |command|
            Roast::Tools.register_function(
              :cmd,
              command,
              "Run #{command} command in a safe, controlled environment",
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

              Roast::Tools::Cmd.execute_allowed_command(full_command, command, timeout: params[:timeout])
            end
          end
        end

        def configuration
          Roast.configuration
        end
      end

      def execute_allowed_command(full_command, command_prefix, timeout: 30)
        Roast::Helpers::Logger.info("🔧 Running command: #{full_command}\n")

        if timeout && timeout > 0
          execute_command_with_timeout(full_command, command_prefix, timeout: timeout)
        else
          execute_command(full_command, command_prefix)
        end
      rescue StandardError => e
        handle_error(e)
      end

      # Legacy method for backward compatibility
      def call(command, config = {}, timeout: 30)
        Roast::Helpers::Logger.info("🔧 Running command: #{command}\n")

        allowed_commands = config[CONFIG_ALLOWED_COMMANDS] || DEFAULT_ALLOWED_COMMANDS
        validation_result = validate_command(command, allowed_commands)
        return validation_result unless validation_result.nil?

        if timeout && timeout > 0
          execute_command_with_timeout(command, command.split(" ").first, timeout: timeout)
        else
          execute_command(command, command.split(" ").first)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      def validate_command(command, allowed_commands)
        command_prefix = command.split(" ").first

        unless allowed_commands.include?(command_prefix)
          return "Error: Command '#{command_prefix}' is not allowed. Allowed commands: #{allowed_commands.join(", ")}"
        end

        nil
      end

      def handle_error(error)
        Roast::Helpers::Logger.error("Command execution failed: #{error.message}\n")
        "Error: #{error.message}"
      end

      def format_output(command, result, exit_status)
        if exit_status == 0
          result
        else
          "Command '#{command}' failed with exit status #{exit_status}:\n#{result}"
        end
      end

      def tool_config
        configuration&.tool_config("Roast::Tools::Cmd") || {}
      end

      def execute_command_with_timeout(command, command_prefix, timeout:)
        timeout = Roast::Helpers::TimeoutHandler.validate_timeout(timeout)

        full_command = if command_prefix == "dev"
          "bash -l -c '#{command.gsub("'", "\\'")}'"
        else
          command
        end

        result, exit_status = Roast::Helpers::TimeoutHandler.call(
          full_command,
          timeout: timeout,
          working_directory: Dir.pwd,
        )

        format_output(command, result, exit_status)
      rescue Timeout::Error => e
        Roast::Helpers::Logger.error(e.message + "\n")
        e.message
      end

      def execute_command(command, command_prefix)
        result = if command_prefix == "dev"
          # Use bash -l -c to ensure we get a login shell with all environment variables
          `bash -l -c '#{command.gsub("'", "\\'")}'`
        else
          `#{command}`
        end

        exit_status = $CHILD_STATUS.exitstatus
        format_output(command, result, exit_status)
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
