# frozen_string_literal: true

module Roast
  module Tools
    module Bash
      extend self

      class << self
        def included(base)
          base.class_eval do
            function(
              :bash,
              "Execute any bash command without restrictions. ⚠️ WARNING: Use only in trusted environments!",
              command: { type: "string", description: "The bash command to execute" },
            ) do |params|
              Roast::Tools::Bash.call(params[:command])
            end
          end
        end
      end

      def call(command)
        Roast::Helpers::Logger.info("🚀 Executing bash command: #{command}\n")

        # Show warning unless explicitly disabled
        if ENV["ROAST_BASH_WARNINGS"] != "false"
          Roast::Helpers::Logger.warn("⚠️  WARNING: Unrestricted bash execution - use with caution!\n")
        end

        # Execute the command without any restrictions
        result = ""
        IO.popen("#{command} 2>&1", chdir: Dir.pwd) do |io|
          result = io.read
        end

        exit_status = $CHILD_STATUS.exitstatus

        format_output(command, result, exit_status)
      rescue StandardError => e
        handle_error(e)
      end

      private

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
