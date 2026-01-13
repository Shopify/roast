# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Codex < Provider
            class CodexInvocation
              class CodexInvocationError < Roast::Error; end

              class CodexNotStartedError < CodexInvocationError; end

              class CodexAlreadyStartedError < CodexInvocationError; end

              class CodexNotCompletedError < CodexInvocationError; end

              class CodexFailedError < CodexInvocationError; end

              class Result
                #: String
                attr_accessor :response

                #: bool
                attr_accessor :success

                #: String?
                attr_accessor :session

                #: Stats?
                attr_accessor :stats

                def initialize
                  @response = ""
                  @success = false
                end
              end

              #: (Agent::Config, Agent::Input) -> void
              def initialize(config, input)
                @base_command = config.valid_command #: (String | Array[String])?
                @model = config.valid_model #: String?
                @append_system_prompt = config.valid_append_system_prompt #: String?
                @replace_system_prompt = config.valid_replace_system_prompt #: String?
                @apply_permissions = config.apply_permissions? #: bool
                @working_directory = config.valid_working_directory #: Pathname?
                @prompt = input.valid_prompt! #: String
                @session = input.session #: String?
                @result = Result.new #: Result
                @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
                @show_progress = config.show_progress? #: bool
              end

              #: () -> void
              def run!
                raise CodexAlreadyStartedError if started?

                @started = true
                stdout, stderr, status = CommandRunner.execute(
                  command_line,
                  working_directory: @working_directory,
                  stdout_handler: lambda { |line| handle_stdout(line) },
                )

                if status.success?
                  @completed = true
                  @result.success = true
                  # If no streaming output was captured, use the full stdout
                  @result.response = stdout.strip if @result.response.blank?
                else
                  @failed = true
                  @result.success = false
                  @result.response += "\n" unless @result.response.blank? || @result.response.ends_with?("\n")
                  @result.response += stderr
                end
              end

              #: () -> bool
              def started?
                @started ||= false
              end

              #: () -> bool
              def running?
                started? && !completed? && !failed?
              end

              #: () -> bool
              def completed?
                @completed ||= false
              end

              #: () -> bool
              def failed?
                @failed ||= false
              end

              #: () -> Result
              def result
                raise CodexNotStartedError unless started?
                raise CodexFailedError, @result.response if failed?
                raise CodexNotCompletedError, @result.response unless completed?

                @result
              end

              private

              #: (String) -> void
              def handle_stdout(line)
                line = line.strip
                return if line.empty?

                # Dump raw output if configured
                if @raw_dump_file
                  File.open(@raw_dump_file, "a") { |f| f.puts(line) }
                end

                # Try to parse as JSON (Codex can output JSON with --json flag)
                begin
                  data = JSON.parse(line)
                  handle_json_message(data)
                rescue JSON::ParserError
                  # Plain text output - accumulate it
                  handle_text_output(line)
                end
              end

              #: (Hash[String, untyped]) -> void
              def handle_json_message(data)
                # Handle JSON Lines format from codex exec --json
                type = data["type"]

                case type
                when "message"
                  content = data.dig("content") || data.dig("message")
                  if content.is_a?(String)
                    @result.response += content
                    puts content if @show_progress
                  end
                when "result", "final"
                  content = data.dig("content") || data.dig("message") || data.dig("result")
                  @result.response = content.to_s if content
                when "error"
                  error_msg = data.dig("message") || data.dig("error") || "Unknown error"
                  @result.response += "\nError: #{error_msg}"
                else
                  # Unknown JSON format, try to extract content
                  if data["content"]
                    @result.response += data["content"].to_s
                    puts data["content"] if @show_progress
                  elsif data["message"]
                    @result.response += data["message"].to_s
                    puts data["message"] if @show_progress
                  end
                end
              end

              #: (String) -> void
              def handle_text_output(line)
                @result.response += line + "\n"
                puts line if @show_progress
              end

              #: () -> Array[String]
              def command_line
                command = if @base_command.is_a?(Array)
                  @base_command.dup
                elsif @base_command.is_a?(String)
                  @base_command.split
                else
                  ["codex"]
                end

                # Codex uses 'exec' subcommand for non-interactive mode
                command.push("exec") unless command.include?("exec")

                # Add the prompt
                command.push(@prompt)

                # Add model if specified
                command.push("--model", @model) if @model

                # Add system prompt options
                # Note: Codex uses different flags than Claude
                if @replace_system_prompt
                  command.push("--instructions", @replace_system_prompt)
                end

                if @append_system_prompt
                  # Codex doesn't have append-system-prompt, so we prepend to the prompt
                  # This is handled by modifying the prompt in the input
                end

                # Add full-auto mode for edits (equivalent to skipping permissions)
                command << "--full-auto" unless @apply_permissions

                # Resume session if provided
                if @session.present?
                  command.push("resume", @session)
                end

                command
              end
            end
          end
        end
      end
    end
  end
end
