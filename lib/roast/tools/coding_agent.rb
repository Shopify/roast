# frozen_string_literal: true

module Roast
  module Tools
    module CodingAgent
      extend self

      class CodingAgentError < StandardError; end

      CONFIG_CODING_AGENT_COMMAND = "coding_agent_command"
      private_constant :CONFIG_CODING_AGENT_COMMAND

      @configured_command = nil

      class << self
        attr_accessor :configured_command

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

        # Called after configuration is loaded
        def post_configuration_setup(base, config = {})
          self.configured_command = config[CONFIG_CODING_AGENT_COMMAND]
        end
      end

      def call(prompt)
        Roast::Helpers::Logger.info("🤖 Running CodingAgent\n")
        run_claude_code(prompt)
      rescue StandardError => e
        "Error running CodingAgent: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      private

      def run_claude_code(prompt)
        Roast::Helpers::Logger.debug("🤖 Executing Claude Code CLI with prompt: #{prompt}\n")

        # Create a temporary file with a unique name
        timestamp = Time.now.to_i
        random_id = SecureRandom.hex(8)
        pid = Process.pid
        temp_file = Tempfile.new(["claude_prompt_#{timestamp}_#{pid}_#{random_id}", ".txt"])

        begin
          # Write the prompt to the file
          temp_file.write(prompt)
          temp_file.close

          # Run Claude Code CLI using the temp file as input with streaming output
          expect_json_output = claude_code_command.include?("--output-format stream-json") ||
            claude_code_command.include?("--output-format json")
          command = "cat #{temp_file.path} | #{claude_code_command}"
          result = ""

          Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
            stdin.close
            if expect_json_output
              stdout.each_line do |line|
                json = parse_json(line)
                next unless json

                handle_intermediate_message(json)
                result += handle_result(json) || ""
              end
            else
              result = stdout.read
            end

            status = wait_thread.value
            if status.success?
              return result
            else
              error_output = stderr.read
              return "Error running CodingAgent: #{error_output}"
            end
          end
        ensure
          # Always clean up the temp file
          temp_file.unlink
        end
      end

      def parse_json(line)
        JSON.parse(line)
      rescue JSON::ParserError => e
        Roast::Helpers::Logger.warn("🤖 Error parsing JSON response: #{e}\n")
        nil
      end

      def handle_intermediate_message(json)
        case json["type"]
        when "assistant", "user"
          Roast::Tools::Helpers::CodingAgentMessageFormatter.format_messages(json).each(&method(:log_message))
        when "result", "system"
          # Ignore these message types
        else
          Roast::Helpers::Logger.debug("🤖 Encountered unexpected message type: #{json["type"]}\n")
        end
      end

      def handle_result(json)
        if json["type"] == "result"
          # NOTE: the format of an error response is { "subtype": "success", "is_error": true }
          if json["is_error"]
            raise CodingAgentError, json["result"]
          elsif json["subtype"] == "success"
            json["result"]
          else
            raise CodingAgentError, "CodingAgent did not complete successfully: #{line}"
          end
        end
      end

      def log_message(text)
        return if text.blank?

        text = text.lines.map do |line|
          "\t#{line}"
        end.join
        Roast::Helpers::Logger.info("• " + text.chomp + "\n")
      end

      def claude_code_command
        CodingAgent.configured_command || ENV["CLAUDE_CODE_COMMAND"] || "claude -p --verbose --output-format stream-json"
      end
    end
  end
end
