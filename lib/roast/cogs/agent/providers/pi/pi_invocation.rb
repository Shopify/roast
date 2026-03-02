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
              @result = Result.new #: Result
              @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
              @show_progress = config.show_progress? #: bool
            end

            #: () -> void
            def run!
              raise PiAlreadyStartedError if started?

              @started = true
              start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

              _stdout, stderr, status = CommandRunner.execute(
                command_line,
                working_directory: @working_directory,
                stdin_content: @prompt,
                stdout_handler: lambda { |line| handle_stdout(line) },
              )

              duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

              if status.success?
                @completed = true
                @result.stats ||= Stats.new
                @result.stats.duration_ms = duration_ms
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
              return if line.empty?

              message = Message.from_json(line, raw_dump_file: @raw_dump_file)
              return unless message

              handle_message(message)
            end

            #: (Message) -> void
            def handle_message(message)
              case message
              when Messages::SessionMessage
                @result.session = message.session_id
              when Messages::AgentEndMessage
                @result.response = message.final_response
                @result.success = true
              when Messages::TurnEndMessage
                accumulate_turn_stats(message)
              when Messages::MessageUpdateMessage
                # Show progress for text deltas
                formatted = message.format
                puts formatted if formatted.present? && @show_progress
              end

              unless message.unparsed.blank?
                Roast::Log.debug("Unhandled data in Pi #{message.type} message:")
                Roast::Log.debug(JSON.pretty_generate(message.unparsed))
              end
            end

            #: (Messages::TurnEndMessage) -> void
            def accumulate_turn_stats(message)
              @result.stats ||= Stats.new
              stats = @result.stats.not_nil!
              stats.num_turns = (stats.num_turns || 0) + 1

              usage = message.usage
              return unless usage

              model = message.model || "unknown"
              model_usage = stats.model_usage[model] ||= Usage.new
              model_usage.input_tokens = (model_usage.input_tokens || 0) + (usage[:input] || 0)
              model_usage.output_tokens = (model_usage.output_tokens || 0) + (usage[:output] || 0)

              cost = usage[:cost]
              if cost
                model_usage.cost_usd = (model_usage.cost_usd || 0.0) + (cost[:total] || 0)
                stats.usage.cost_usd = (stats.usage.cost_usd || 0.0) + (cost[:total] || 0)
              end

              stats.usage.input_tokens = (stats.usage.input_tokens || 0) + (usage[:input] || 0)
              stats.usage.output_tokens = (stats.usage.output_tokens || 0) + (usage[:output] || 0)
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
