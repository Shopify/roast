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

              class Context
                def initialize
                  @tool_uses = {} #: Hash[String, Messages::ToolUseMessage]
                end

                #: (String?) -> Messages::ToolUseMessage?
                def tool_use(tool_use_id)
                  @tool_uses[tool_use_id] if tool_use_id
                end

                #: (Messages::ToolUseMessage) -> void
                def add_tool_use(tool_use_message)
                  id = tool_use_message.id
                  @tool_uses[id] = tool_use_message if id
                end
              end

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
                @append_system_prompt = config.valid_initial_prompt #: String?
                @apply_permissions = config.apply_permissions? #: bool
                @working_directory = config.valid_working_directory #: Pathname?
                @prompt = input.valid_prompt! #: String
                @session = input.session #: String?
                @context = Context.new #: Context
                @result = Result.new #: Result
                @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
                @show_progress = config.show_progress? #: bool
              end

              #: () -> void
              def run!
                raise ClaudeAlreadyStartedError if started?

                @started = true
                _stdout, stderr, status = CommandRunner.execute(
                  command_line,
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
                raise ClaudeFailedError, @result.response if failed?
                raise ClaudeNotCompletedError, @result.response unless completed?

                @result
              end

              private

              #: (String) -> void
              def handle_stdout(line)
                line = line.strip
                message = Message.from_json(line, raw_dump_file: @raw_dump_file) unless line.empty?
                return unless message

                handle_message(message)
              end

              #: (Message) -> void
              def handle_message(message)
                case message
                when Messages::AssistantMessage
                  message.messages.each { |msg| handle_message(msg) }
                when Messages::ResultMessage
                  @result.response = message.content
                  @result.success = message.success
                  @result.stats = message.stats
                when Messages::ToolUseMessage
                  @context.add_tool_use(message)
                when Messages::UserMessage
                  message.messages.each { |msg| handle_message(msg) }
                end

                @result.session = message.session_id if message.session_id.present?

                formatted_message = message.format(@context)
                puts formatted_message if formatted_message.present? && @show_progress

                puts "[AGENT MESSAGE: #{message.type}] #{message.inspect}" unless message.unparsed.blank?
                # TODO: do something better with unhandled data so we can improve the parser
                puts "[WARNING] Unhandled data in Claude #{message.type} message: #{message.unparsed}\n" unless message.unparsed.blank?
              end

              #: () -> Array[String]
              def command_line
                command = if @base_command.is_a?(Array)
                  @base_command.dup
                elsif @base_command.is_a?(String)
                  @base_command.split
                else
                  ["claude"]
                end
                command.push("-p", "--verbose", "--output-format", "stream-json")
                command.push("--model", @model) if @model
                command.push("--append-system-prompt", @append_system_prompt) if @append_system_prompt
                command.push("--fork-session", "--resume", @session) if @session.present?
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
