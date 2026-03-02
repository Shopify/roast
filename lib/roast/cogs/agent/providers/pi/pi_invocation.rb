# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class PiInvocation
            class PiInvocationError < Roast::Error; end

            class PiNotStartedError < PiInvocationError; end

            class PiAlreadyStartedError < PiInvocationError; end

            class PiNotCompletedError < PiInvocationError; end

            class PiFailedError < PiInvocationError; end

            class Context
              def initialize
                @tool_calls = {} #: Hash[String, Messages::ToolCallEndMessage]
              end

              #: (String?) -> Messages::ToolCallEndMessage?
              def tool_call(tool_call_id)
                @tool_calls[tool_call_id] if tool_call_id
              end

              #: (Messages::ToolCallEndMessage) -> void
              def add_tool_call(tool_call_end_message)
                id = tool_call_end_message.tool_call_id
                @tool_calls[id] = tool_call_end_message if id
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
              @append_system_prompt = config.valid_append_system_prompt #: String?
              @replace_system_prompt = config.valid_replace_system_prompt #: String?
              @working_directory = config.valid_working_directory #: Pathname?
              @prompt = input.valid_prompt! #: String
              @session = input.session #: String?
              @context = Context.new #: Context
              @result = Result.new #: Result
              @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
              @show_progress = config.show_progress? #: bool
              @num_turns = 0 #: Integer
            end

            #: () -> void
            def run!
              raise PiAlreadyStartedError if started?

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
              raise PiNotStartedError unless started?
              raise PiFailedError, @result.response if failed?
              raise PiNotCompletedError, @result.response unless completed?

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
              when Messages::SessionMessage
                @result.session = message.session_id
              when Messages::AgentEndMessage
                @result.response = message.response
                @result.success = message.success
                stats = message.stats
                stats.num_turns = @num_turns
                @result.stats = stats
              when Messages::TurnEndMessage
                @num_turns += 1
              when Messages::ToolCallEndMessage
                @context.add_tool_call(message)
              end

              formatted_message = message.format(@context)
              puts formatted_message if formatted_message.present? && @show_progress

              unless message.unparsed.blank?
                Roast::Log.warn("Unhandled data in Pi #{message.type} message:")
                Roast::Log.warn(JSON.pretty_generate(message.unparsed))
                Roast::Log.debug("[FULL MESSAGE: #{message.type}]")
                Roast::Log.debug(message.inspect)
              end
            end

            #: () -> Array[String]
            def command_line
              command = if @base_command.is_a?(Array)
                @base_command.dup
              elsif @base_command.is_a?(String)
                @base_command.split
              else
                ["pi"]
              end
              command.push("-p", "--mode", "json")
              command.push("--model", @model) if @model
              command.push("--system-prompt", @replace_system_prompt) if @replace_system_prompt
              command.push("--append-system-prompt", @append_system_prompt) if @append_system_prompt
              command.push("--session", @session) if @session.present?
              command
            end
          end
        end
      end
    end
  end
end
