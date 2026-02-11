# typed: true
# frozen_string_literal: true

module Roast
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
              @working_directory = config.valid_working_directory #: Pathname?
              @prompt = input.valid_prompt! #: String
              @session = input.session #: String?
              @result = Result.new #: Result
              @raw_dump_file = config.valid_dump_raw_agent_messages_to_path #: Pathname?
              @show_progress = config.show_progress? #: bool
              @num_turns = 0 #: Integer
            end

            #: () -> void
            def run!
              raise OpencodeAlreadyStartedError if started?

              @started = true
              _stdout, stderr, status = CommandRunner.execute(
                command_line,
                working_directory: @working_directory,
                stdout_handler: lambda { |line| handle_stdout(line) },
              )

              if status.success?
                @completed = true
                @result.success = true
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

              dump_raw_line(line)

              begin
                event = JSON.parse(line)
              rescue JSON::ParserError => e
                Roast::Log.warn("Failed to parse opencode JSON output: #{e.message}")
                return
              end

              handle_event(event)
            end

            #: (Hash[String, untyped]) -> void
            def handle_event(event)
              type = event["type"]

              case type
              when "text"
                handle_text_event(event)
              when "step_start"
                handle_step_start_event(event)
              when "step_finish"
                handle_step_finish_event(event)
              end
            end

            #: (Hash[String, untyped]) -> void
            def handle_text_event(event)
              text = event.dig("part", "text")
              return unless text

              @result.response += text
              print(text) if @show_progress
            end

            #: (Hash[String, untyped]) -> void
            def handle_step_start_event(event)
              session_id = event["sessionID"]
              @result.session = session_id if session_id.present?
              @num_turns += 1
            end

            #: (Hash[String, untyped]) -> void
            def handle_step_finish_event(event)
              part = event["part"]
              return unless part

              stats = @result.stats ||= Stats.new
              stats.num_turns = @num_turns

              cost = part["cost"]
              tokens = part["tokens"]

              if cost
                stats.usage.cost_usd = (stats.usage.cost_usd || 0.0) + cost
              end

              if tokens
                input_tokens = tokens["input"]
                output_tokens = tokens["output"]

                if input_tokens
                  stats.usage.input_tokens = (stats.usage.input_tokens || 0) + input_tokens
                end

                if output_tokens
                  stats.usage.output_tokens = (stats.usage.output_tokens || 0) + output_tokens
                end
              end
            end

            #: (String) -> void
            def dump_raw_line(line)
              return unless @raw_dump_file

              File.open(@raw_dump_file, "a") { |f| f.puts(line) }
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

              command.push("run") unless command.include?("run")
              command.push("--format", "json")
              command.push("--model", @model) if @model
              command.push("--session", @session, "--fork") if @session.present?
              command.push(@prompt)
              command
            end
          end
        end
      end
    end
  end
end
