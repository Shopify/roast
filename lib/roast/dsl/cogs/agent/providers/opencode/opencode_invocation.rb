# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Opencode < Provider
            class OpencodeInvocation
              class OpencodeInvocationError < Roast::Error; end

              class OpencodeNotStartedError < OpencodeInvocationError; end

              class OpencodeAlreadyStartedError < OpencodeInvocationError; end

              class OpencodeNotCompletedError < OpencodeInvocationError; end

              class OpencodeFailedError < OpencodeInvocationError; end

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
                raise OpencodeAlreadyStartedError if started?

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
                raise OpencodeNotStartedError unless started?
                raise OpencodeFailedError, @result.response if failed?
                raise OpencodeNotCompletedError, @result.response unless completed?

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

                # opencode outputs plain text, accumulate it
                handle_text_output(line)
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
                  ["opencode"]
                end

                # Add model if specified
                command.push("--model", @model) if @model

                # opencode uses 'run' subcommand for non-interactive mode
                command.push("run") unless command.include?("run")

                # Add system prompt if specified
                # opencode uses --system for system prompts
                if @replace_system_prompt
                  command.push("--system", @replace_system_prompt)
                end

                # Add the prompt
                command.push(@prompt)

                command
              end
            end
          end
        end
      end
    end
  end
end
