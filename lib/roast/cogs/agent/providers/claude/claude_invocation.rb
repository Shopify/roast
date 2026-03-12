# typed: true
# frozen_string_literal: true

module Roast
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

            #: (Agent::Config, String, String?, ?fork_session: bool) -> void
            def initialize(config, prompt, session, fork_session: true)
              @base_command = config.valid_command #: (String | Array[String])?
              @model = config.valid_model #: String?
              @append_system_prompt = config.valid_append_system_prompt #: String?
              @replace_system_prompt = config.valid_replace_system_prompt #: String?
              @apply_permissions = config.apply_permissions? #: bool
              @working_directory = config.valid_working_directory #: Pathname?
              @context = Context.new #: Context
              @result = Result.new #: Result
              @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
              @show_prompt = config.show_prompt? #: bool
              @show_progress = config.show_progress? #: bool
              @show_response = config.show_response? #: bool
              @prompt = prompt
              @session = session
              @fork_session = fork_session #: bool
            end

            #: () -> void
            def run!
              raise ClaudeAlreadyStartedError if started?

              @started = true
              puts "[USER PROMPT] #{@prompt}" if @show_prompt
              _stdout, stderr, status = CommandRunner.execute(
                command_line,
                working_directory: @working_directory,
                stdin_content: @prompt,
                stdout_handler: lambda { |line| handle_stdout(line) },
              )

              if status.success?
                @completed = true
                puts "[AGENT RESPONSE] #{@result.response}" if @show_response
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

              if message.session_id.present?
                (Event << { debug: "New Claude Session ID: #{message.session_id}" }) if @result.session != message.session_id
                @result.session = message.session_id
              end

              formatted_message = message.format(@context)
              puts formatted_message if formatted_message.present? && @show_progress

              unless message.unparsed.blank?
                # TODO: do something better with unhandled data so we can improve the parser
                Event << {
                  debug: <<~DEBUG,
                    Unhandled data in Claude #{message.type} message:
                      #{JSON.pretty_generate(message.unparsed)}
                  DEBUG
                }
              end

              raise ClaudeFailedError, message.error if message.error.present?
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
              command.push("--system-prompt", @replace_system_prompt) if @replace_system_prompt
              command.push("--append-system-prompt", @append_system_prompt) if @append_system_prompt
              if @session.present?
                command.push("--fork-session") if @fork_session
                command.push("--resume", @session)
              end
              command << "--dangerously-skip-permissions" unless @apply_permissions
              command
            end
          end
        end
      end
    end
  end
end
