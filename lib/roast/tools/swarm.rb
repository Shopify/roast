# typed: false
# frozen_string_literal: true

require "shellwords"

module Roast
  module Tools
    module Swarm
      extend self

      DEFAULT_CONFIG_PATHS = [
        ".swarm.yml",
        "swarm.yml",
        ".swarm/config.yml",
      ].freeze

      CONFIG_PATH_KEY = "path"
      private_constant :DEFAULT_CONFIG_PATHS, :CONFIG_PATH_KEY

      class << self
        def included(base)
          base.class_eval do
            function(
              :swarm,
              "Execute Claude Swarm to orchestrate multiple Claude Code instances",
              prompt: {
                type: "string",
                description: "The prompt to send to the swarm agents",
                required: true,
              },
              path: {
                type: "string",
                description: "Path to the swarm configuration file (optional)",
                required: false,
              },
            ) do |params|
              Roast::Tools::Swarm.call(params[:prompt], params[:path])
            end
          end
        end

        def post_configuration_setup(base, config = {})
          @tool_config = config
        end

        attr_reader :tool_config
      end

      def call(prompt, step_path = nil)
        config_path = determine_config_path(step_path)

        if config_path.nil?
          return "Error: No swarm configuration file found. Please create a .swarm.yml file or specify a path."
        end

        unless File.exist?(config_path)
          return "Error: Swarm configuration file not found at: #{config_path}"
        end

        Roast::Helpers::Logger.info("🐝 Running Claude Swarm with config: #{config_path}\n")

        execute_swarm(prompt, config_path)
      rescue Roast::Error => e
        handle_error(e)
      end

      private

      def determine_config_path(step_path)
        # Priority: step-level path > tool-level path > default locations

        # 1. Check step-level path
        return step_path if step_path

        # 2. Check tool-level path from configuration
        if tool_config && tool_config[CONFIG_PATH_KEY]
          return tool_config[CONFIG_PATH_KEY]
        end

        # 3. Check default locations
        DEFAULT_CONFIG_PATHS.find { |path| File.exist?(path) }
      end

      def execute_swarm(prompt, config_path)
        # Build the swarm command with proper escaping
        command = build_swarm_command(prompt, config_path)

        # Execute the command directly with the prompt included
        result, status = Roast::Helpers::CmdRunner.capture2e(command)
        exit_status = status.exitstatus

        format_output(command, result, exit_status)
      end

      def build_swarm_command(prompt, config_path)
        # Build the claude-swarm command with properly escaped arguments
        [
          "claude-swarm",
          "--config",
          config_path,
          "--prompt",
          prompt,
        ].shelljoin
      end

      def format_output(command, result, exit_status)
        "Command: #{command}\n" \
          "Exit status: #{exit_status}\n" \
          "Output:\n#{result}"
      end

      def handle_error(error)
        error_message = "Error running swarm: #{error.message}"
        Roast::Helpers::Logger.error("#{error_message}\n")
        Roast::Helpers::Logger.debug("#{error.backtrace.join("\n")}\n") if ENV["DEBUG"]
        error_message
      end
    end
  end
end
