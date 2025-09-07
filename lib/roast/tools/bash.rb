# typed: false
# frozen_string_literal: true

require "English"
require "roast/helpers/logger"

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
              timeout: { type: "integer", description: "Timeout in seconds (optional, default: 30)", required: false },
            ) do |params|
              Roast::Tools::Bash.call(params[:command], timeout: params[:timeout])
            end
          end
        end
      end

      def call(command, timeout: 30)
        Roast::Helpers::Logger.info("🚀 Executing bash command: #{command}\n")

        # Show warning unless explicitly disabled
        if ENV["ROAST_BASH_WARNINGS"] != "false"
          Roast::Helpers::Logger.warn("⚠️  WARNING: Unrestricted bash execution - use with caution!\n")
        end

        timeout = Roast::Helpers::CmdRunner.normalize_timeout(timeout)

        result, status = Roast::Helpers::CmdRunner.capture2e(
          "#{command} 2>&1",
          timeout: timeout,
        )

        format_output(command, result, status.exitstatus)
      rescue Timeout::Error => e
        Roast::Helpers::Logger.error(e.message + "\n")
        e.message
      rescue Roast::Error => e
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
