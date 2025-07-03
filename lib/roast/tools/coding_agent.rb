# frozen_string_literal: true

module Roast
  module Tools
    module CodingAgent
      extend self

      class CodingAgentError < StandardError; end

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
              "AI-powered coding agent that runs an instance of the Claude Code agent with the given prompt. If the agent is iterating on previous work, set continue to true. To resume from a specific previous session, set resume to the step name.",
              prompt: { type: "string", description: "The prompt to send to Claude Code" },
              include_context_summary: { type: "boolean", description: "Whether to set a summary of the current workflow context as system directive (default: false)", required: false },
              continue: { type: "boolean", description: "Whether to continue where the previous coding agent left off or start with a fresh context (default: false, start fresh)", required: false },
              resume: { type: "string", description: "The name of a previous step to resume the coding agent session from (takes precedence over continue)", required: false },
            ) do |params|
              Roast::Tools::CodingAgent.call(
                params[:prompt],
                include_context_summary: params[:include_context_summary].presence || false,
                continue: params[:continue].presence || false,
                resume: params[:resume].presence,
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

      def call(prompt, include_context_summary: false, continue: false, resume: nil)
        Roast::Helpers::Logger.info("🤖 Running CodingAgent\n")
        run_claude_code(prompt, include_context_summary:, continue:, resume:)
      rescue StandardError => e
        "Error running CodingAgent: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      private

      def run_claude_code(prompt, include_context_summary:, continue:, resume:)
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

          # Resolve session ID if resume is specified
          session_id = resolve_session_id(resume) if resume

          # Build the command with continue or resume option if specified
          base_command = claude_code_command
          command_to_run = build_command(base_command, continue:, session_id:)

          Roast::Helpers::Logger.debug(command_to_run)

          # Run Claude Code CLI using the temp file as input with streaming output
          expect_json_output = command_to_run.include?("--output-format stream-json") ||
            command_to_run.include?("--output-format json")
          command = "cat #{temp_file.path} | #{command_to_run}"
          result = ""
          final_session_id = nil

          Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
            stdin.close
            if expect_json_output
              stdout.each_line do |line|
                json = parse_json(line)
                next unless json

                handle_intermediate_message(json)

                # Track session ID from any message
                final_session_id = json["session_id"] if json["session_id"]

                result += handle_result(json) || ""
              end
            else
              result = stdout.read
            end

            status = wait_thread.value
            if status.success?
              # Store session ID for potential future resume operations
              store_session_id(final_session_id) if final_session_id
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
            raise CodingAgentError, "CodingAgent did not complete successfully: #{json.inspect}"
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
        CodingAgent.configured_command || ENV["CLAUDE_CODE_COMMAND"] || "claude -p --verbose --output-format stream-json --dangerously-skip-permissions"
      end

      def build_command(base_command, continue:, session_id: nil)
        command = base_command.dup

        # Add configured options (like --model)
        if CodingAgent.configured_options.any?
          options_str = build_options_string(CodingAgent.configured_options)
          command = if command.start_with?("claude ")
            command.sub("claude ", "claude #{options_str} ")
          else
            # For non-standard commands, append at the end
            "#{command} #{options_str}"
          end
        end

        # Add --resume or --continue flag if needed
        if session_id
          # Add --resume flag with session ID to the command
          command = if command.start_with?("claude ")
            command.sub("claude ", "claude --resume #{session_id} ")
          else
            # Fallback for non-standard commands
            "#{command} --resume #{session_id}"
          end
        elsif continue
          # Add --continue flag to the command
          command = if command.start_with?("claude ")
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

      def resolve_session_id(step_name)
        # Access the current workflow context to look up session IDs
        workflow_context = Thread.current[:workflow_context]
        return unless workflow_context

        workflow = workflow_context.workflow
        return unless workflow.respond_to?(:output)

        # Look for session ID in the specified step's output
        step_output = workflow.output[step_name]
        return unless step_output.is_a?(Hash)

        session_id = step_output["session_id"]
        if session_id
          Roast::Helpers::Logger.debug("🤖 Resuming from session ID: #{session_id} (from step: #{step_name})\n")
          session_id
        else
          Roast::Helpers::Logger.warn("🤖 No session ID found for step '#{step_name}'. Starting fresh session.\n")
          nil
        end
      rescue => e
        Roast::Helpers::Logger.debug("Failed to resolve session ID for step '#{step_name}': #{e.message}\n")
        nil
      end

      def store_session_id(session_id)
        # Access the current workflow context to store session IDs
        workflow_context = Thread.current[:workflow_context]
        return unless workflow_context

        workflow = workflow_context.workflow
        return unless workflow.respond_to?(:output)

        # Get the current step name
        step_name = current_step_name
        return unless step_name

        # Ensure the step output is a hash and store the session ID
        workflow.output[step_name] ||= {}
        if workflow.output[step_name].is_a?(Hash)
          workflow.output[step_name]["session_id"] = session_id
          Roast::Helpers::Logger.debug("🤖 Stored session ID: #{session_id} for step: #{step_name}\n")
        elsif workflow.output[step_name].is_a?(String)
          # If the current output is a string, convert it to a hash preserving the original content
          original_content = workflow.output[step_name]
          workflow.output[step_name] = {
            "content" => original_content,
            "session_id" => session_id,
          }
          Roast::Helpers::Logger.debug("🤖 Converted string output to hash and stored session ID: #{session_id} for step: #{step_name}\n")
        end
      rescue => e
        Roast::Helpers::Logger.debug("Failed to store session ID '#{session_id}' for step '#{step_name}': #{e.message}\n")
        nil
      end

      def current_step_name
        # Access the current step name if available in the context
        Thread.current[:current_step_name]
      rescue => e
        Roast::Helpers::Logger.debug("Failed to get current step name: #{e.message}\n")
        nil
      end
    end
  end
end
