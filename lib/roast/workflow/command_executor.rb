# frozen_string_literal: true

require "English"

module Roast
  module Workflow
    class CommandExecutor
      class CommandExecutionError < StandardError
        attr_reader :command, :exit_status, :original_error, :output

        def initialize(message, command:, exit_status: nil, original_error: nil)
          @command = command
          @exit_status = exit_status
          @original_error = original_error
          super(message)
        end
      end

      def initialize(logger: nil)
        @logger = logger || NullLogger.new
      end

      def execute(command_string, exit_on_error: true)
        command = extract_command(command_string)

        output = %x(#{command})
        exit_status = $CHILD_STATUS.exitstatus

        handle_execution_result(
          command: command,
          output: output,
          exit_status: exit_status,
          success: $CHILD_STATUS.success?,
          exit_on_error: exit_on_error,
        )
      rescue ArgumentError, CommandExecutionError
        raise
      rescue => e
        handle_execution_error(
          command: command,
          error: e,
          exit_on_error: exit_on_error,
        )
      end

      private

      def extract_command(command_string)
        match = command_string.strip.match(/^\$\((.*)\)$/)
        raise ArgumentError, "Invalid command format. Expected $(command), got: #{command_string}" unless match

        match[1]
      end

      def handle_execution_result(command:, output:, exit_status:, success:, exit_on_error:)
        return output if success

        if exit_on_error
          error = CommandExecutionError.new(
            "Command exited with non-zero status (#{exit_status})",
            command: command,
            exit_status: exit_status,
          )
          # Store the output in the error
          error.instance_variable_set(:@output, output)
          raise error
        else
          @logger.warn("Command '#{command}' exited with non-zero status (#{exit_status}), continuing execution")
          output + "\n[Exit status: #{exit_status}]"
        end
      end

      def handle_execution_error(command:, error:, exit_on_error:)
        if exit_on_error
          raise CommandExecutionError.new(
            "Failed to execute command '#{command}': #{error.message}",
            command: command,
            original_error: error,
          )
        else
          @logger.warn("Command '#{command}' failed with error: #{error.message}, continuing execution")
          "Error executing command: #{error.message}\n[Exit status: error]"
        end
      end

      class NullLogger
        def warn(_message); end
      end
    end
  end
end
