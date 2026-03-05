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
              # TODO: implement message parsing in PR 2/3
              line = line.strip
              return if line.empty?

              if @raw_dump_file
                @raw_dump_file.dirname.mkpath
                File.write(@raw_dump_file.to_s, "#{line}\n", mode: "a")
              end

              begin
                parsed = JSON.parse(line, symbolize_names: true)
                handle_message(parsed)
              rescue JSON::ParserError
                Roast::Log.warn("Failed to parse Pi output line: #{line}")
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def handle_message(message)
              type = message[:type]&.to_s

              case type
              when "session"
                @result.session = message[:id]
              when "agent_end"
                extract_result_from_agent_end(message)
              when "turn_end"
                accumulate_turn_stats(message)
              when "message_update"
                handle_message_update(message)
              end
            end

            #: (Hash[Symbol, untyped]) -> void
            def extract_result_from_agent_end(message)
              messages = message[:messages] || []
              last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
              if last_assistant
                text_parts = (last_assistant[:content] || [])
                  .select { |c| c[:type] == "text" }
                  .map { |c| c[:text] }
                @result.response = text_parts.join
              end
              @result.success = true
            end

            #: (Hash[Symbol, untyped]) -> void
            def accumulate_turn_stats(message)
              @result.stats ||= Stats.new
              stats = @result.stats.not_nil!
              stats.num_turns = (stats.num_turns || 0) + 1

              assistant_message = message[:message]
              return unless assistant_message

              usage = assistant_message[:usage]
              return unless usage

              model = assistant_message[:model] || "unknown"
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

            #: (Hash[Symbol, untyped]) -> void
            def handle_message_update(message)
              event = message[:assistantMessageEvent]
              return unless event

              case event[:type]
              when "text_delta"
                delta = event[:delta]
                puts delta if delta && @show_progress
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
