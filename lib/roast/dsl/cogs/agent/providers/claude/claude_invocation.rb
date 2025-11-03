# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            class ClaudeInvocation
              class ClaudeInvocationError < Roast::Error; end

              class ClaudeNotStartedError < ClaudeInvocationError; end

              class ClaudeAlreadyStartedError < ClaudeInvocationError; end

              class ClaudeNotCompletedError < ClaudeInvocationError; end

              class ClaudeFailedError < ClaudeInvocationError; end

              class Result
                #: String
                attr_accessor :response

                #: bool
                attr_accessor :success

                def initialize
                  @response = ""
                  @success = false
                end
              end

              #: (Agent::Config, Agent::Input) -> void
              def initialize(config, input)
                @model = config.valid_model #: String?
                @append_system_prompt = config.valid_initial_prompt #: String?
                @apply_permissions = config.apply_permissions? #: bool
                @working_directory = config.valid_working_directory #: Pathname?
                @prompt = input.valid_prompt! #: String
                @result = Result.new #: Result
              end

              #: () -> void
              def run!
                raise ClaudeAlreadyStartedError if started?

                @started = true
                _stdout, stderr, status = CommandRunner.simple_execute(
                  *T.unsafe(command_line),
                  working_directory: @working_directory,
                  stdin_content: @prompt,
                  stdout_handler: lambda { |line| handle_stdout(line) },
                )

                if status.success?
                  @completed = true
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
                raise ClaudeNotStartedError unless started?
                raise ClaudeFailedError if failed?
                raise ClaudeNotCompletedError unless completed?

                @result
              end

              private

              #: (String) -> void
              def handle_stdout(line)
                line = line.strip
                message = Message.from_json(line) unless line.empty?
                return unless message

                case message
                when Messages::ResultMessage
                  @result.response = message.content
                  @result.success = message.success
                end

                puts
                puts "[AGENT MESSAGE] #{message.inspect}"
                # TODO: do something better with unhandled data so we can improve the parser
                puts "[WARNING] Unhandled data in Claude #{message.type} message: #{message.unparsed}\n" unless message.unparsed.blank?
              end

              #: () -> Array[String]
              def command_line
                command = ["claude", "-p", "--verbose", "--output-format", "stream-json"]
                command << "--model" << @model if @model.present?
                command << "--append-system-prompt" << @append_system_prompt if @append_system_prompt
                command << "--dangerously-skip-permissions" unless @apply_permissions
                command
              end
            end
          end
        end
      end
    end
  end
end
