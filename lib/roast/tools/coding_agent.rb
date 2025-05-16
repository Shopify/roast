# frozen_string_literal: true

require "roast/helpers/logger"
require "open3"
require "tempfile"
require "securerandom"

module Roast
  module Tools
    module CodingAgent
      extend self

      class << self
        def included(base)
          base.class_eval do
            function(
              :coding_agent,
              "AI-powered coding agent that runs Claude Code CLI with the given prompt",
              prompt: { type: "string", description: "The prompt to send to Claude Code" },
            ) do |params|
              Roast::Tools::CodingAgent.call(params[:prompt])
            end
          end
        end
      end

      def call(prompt)
        Roast::Helpers::Logger.info("🤖 Running CodingAgent\n")
        run_claude_code(prompt).tap do |result|
          Roast::Helpers::Logger.info(result)
        end
      rescue StandardError => e
        "Error running CodingAgent: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      private

      def run_claude_code(prompt)
        Roast::Helpers::Logger.info("🤖 Executing Claude Code CLI with prompt: #{prompt}\n")

        # Create a temporary file with a unique name
        timestamp = Time.now.to_i
        random_id = SecureRandom.hex(8)
        pid = Process.pid
        temp_file = Tempfile.new(["claude_prompt_#{timestamp}_#{pid}_#{random_id}", ".txt"])

        begin
          # Write the prompt to the file
          temp_file.write(prompt)
          temp_file.close

          # Run Claude Code CLI using the temp file as input
          claude_code_command = ENV.fetch("CLAUDE_CODE_COMMAND", "claude -p")
          stdout, stderr, status = Open3.capture3("cat #{temp_file.path} | #{claude_code_command}")

          if status.success?
            stdout
          else
            "Error running ClaudeCode: #{stderr}"
          end
        ensure
          # Always clean up the temp file
          temp_file.unlink
        end
      end
    end
  end
end
