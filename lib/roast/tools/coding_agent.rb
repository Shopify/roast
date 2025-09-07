# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module CodingAgent
      extend self
      include Roast::Helpers::MetadataAccess

      class CodingAgentError < Roast::Error; end

      CONFIG_CODING_AGENT_COMMAND = "coding_agent_command"
      private_constant :CONFIG_CODING_AGENT_COMMAND

      @configured_command = nil
      @configured_options = {}

      class << self
        attr_accessor :configured_command, :configured_options

        def included(base)
          base.class_eval do
            function(
              :coding_agent,
              "AI-powered coding agent that runs an instance of the Claude Code agent with the given prompt. If the agent is iterating on previous work, set continue to true.",
              prompt: { type: "string", description: "The prompt to send to Claude Code" },
              include_context_summary: { type: "boolean", description: "Whether to set a summary of the current workflow context as system directive (default: false)", required: false },
              continue: { type: "boolean", description: "Whether to continue where the previous coding agent left off or start with a fresh context (default: false, start fresh)", required: false },
              retries: { type: "integer", description: "Number of times to retry the coding agent invocation if it terminates with an error (default: 0, no retry)", required: false },
            ) do |params|
              Roast::Tools::CodingAgent.call(
                params[:prompt],
                include_context_summary: params[:include_context_summary].presence || false,
                continue: params[:continue].presence || false,
                retries: params[:retries],
              )
            end
          end
        end

        # Called after configuration is loaded
        def post_configuration_setup(base, config = {})
          self.configured_command = config[CONFIG_CODING_AGENT_COMMAND]
          # Store any other configuration options (like model)
          self.configured_options = config.except(CONFIG_CODING_AGENT_COMMAND)
        end
      end

      def call(prompt, include_context_summary: false, continue: false, retries: nil)
        # Use configured retries as default, fall back to 0 if not configured
        retries ||= CodingAgent.configured_options[:retries] || CodingAgent.configured_options["retries"] || 0
        (retries + 1).times do |iteration|
          Roast::Helpers::Logger.info("🤖 Running CodingAgent#{iteration > 0 ? ", attempt #{iteration + 1} of #{retries + 1}" : ""}\n")
          return run_claude_code(prompt, include_context_summary:, continue:)
        rescue CodingAgentError => e
          raise e if iteration >= retries

          Roast::Helpers::Logger.warn("🤖 Retrying after error running CodingAgent: #{e.message}")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
        Roast::Helpers::Logger.error("🤖 CodingAgent did not complete successfully after multiple retries")
      rescue Roast::Error => e
        "🤖 Error running CodingAgent: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      private

      def run_claude_code(prompt, include_context_summary:, continue:)
        Roast::Helpers::Logger.debug("🤖 Executing Claude Code CLI with prompt: #{prompt}\n")

        # Create a temporary file with a unique name
        timestamp = Time.now.to_i
        random_id = SecureRandom.hex(8)
        pid = Process.pid
        temp_file = Tempfile.new(["claude_prompt_#{timestamp}_#{pid}_#{random_id}", ".txt"])

        begin
          # Prepare the final prompt with context summary if requested
          final_prompt = prepare_prompt(prompt, include_context_summary)

          # Write the prompt to the file
          temp_file.write(final_prompt)
          temp_file.close

          # Check for session ID if continue is requested
          # Resuming from a specific session id is more resilient than simply continuing if there are
          # parallel invocations of claude being run in the same working directory.
          session_id = nil
          if continue
            session_id = step_metadata["coding_agent_session_id"]
          end

          # Build the command with continue option (may become resume if session_id exists)
          base_command = claude_code_command
          command_to_run = build_command(base_command, continue:, session_id:)

          Roast::Helpers::Logger.debug(command_to_run)

          # Run Claude Code CLI using the temp file as input with streaming output
          expect_json_output = command_to_run.include?("--output-format stream-json") ||
            command_to_run.include?("--output-format json")
          command = "cat #{temp_file.path} | #{command_to_run}"
          result = ""

          Roast::Helpers::CmdRunner.popen3(command) do |stdin, stdout, stderr, wait_thread|
            stdin.close
            if expect_json_output
              stdout.each_line do |line|
                json = parse_json(line)
                next unless json

                handle_session_info(json)
                handle_intermediate_message(json)
                handled_result = handle_result(json)
                result += handled_result if handled_result
              end
            else
              result = stdout.read
              # Clear any stale session ID we might have when not using JSON formatting
              set_current_step_metadata("coding_agent_session_id", nil)
            end

            status = wait_thread.value
            if status.success?
              return result
            else
              raise CodingAgentError, stderr.read
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
          is_error = json["is_error"] || false
          success = !is_error && json["subtype"] == "success"
          raise CodingAgentError, json.inspect unless success

          json["result"]
        end
      end

      def handle_session_info(json)
        session_id = json["session_id"]
        if session_id
          set_current_step_metadata("coding_agent_session_id", session_id)
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
        CodingAgent.configured_command || ENV["CLAUDE_CODE_COMMAND"] || "claude -p --verbose --output-format stream-json --dangerously-skip-permissions"
      end

      def build_command(base_command, continue:, session_id: nil)
        command = base_command.dup

        # Add configured options (like --model), excluding retries which is handled internally
        options_for_command = CodingAgent.configured_options.except("retries", :retries)
        if options_for_command.any?
          options_str = build_options_string(options_for_command)
          command = if command.start_with?("claude ")
            command.sub("claude ", "claude #{options_str} ")
          else
            # For non-standard commands, append at the end
            "#{command} #{options_str}"
          end
        end

        # Add --resume or --continue flag based on continue option and session_id value
        if continue
          command = if session_id
            # Use --resume with session ID if available
            if command.start_with?("claude ")
              command.sub("claude ", "claude --resume #{session_id} ")
            else
              # Fallback for non-standard commands
              "#{command} --resume #{session_id}"
            end
          elsif command.start_with?("claude ")
            # Use --continue if no session ID
            command.sub("claude ", "claude --continue ")
          else
            # Fallback for non-standard commands
            "#{command} --continue"
          end
        end

        command
      end

      def build_options_string(options)
        options.map do |key, value|
          # Convert Ruby hash keys to command line format
          flag = "--#{key.to_s.tr("_", "-")}"
          if value == true
            flag
          elsif value == false || value.nil?
            nil
          else
            "#{flag} #{value}"
          end
        end.compact.join(" ")
      end

      def prepare_prompt(prompt, include_context_summary)
        return prompt unless include_context_summary

        context_summary = generate_context_summary(prompt)
        return prompt if context_summary.blank? || context_summary == "No relevant information found in the workflow context."

        # Prepend context summary as a system directive
        <<~PROMPT
          <system>
          #{context_summary}
          </system>

          #{prompt}
        PROMPT
      end

      def generate_context_summary(agent_prompt)
        # Access the current workflow context if available
        workflow_context = Thread.current[:workflow_context]
        return unless workflow_context

        # Use ContextSummarizer to generate an intelligent summary
        summarizer = ContextSummarizer.new
        summarizer.generate_summary(workflow_context, agent_prompt)
      rescue => e
        Roast::Helpers::Logger.debug("Failed to generate context summary: #{e.message}\n")
        nil
      end
    end
  end
end
