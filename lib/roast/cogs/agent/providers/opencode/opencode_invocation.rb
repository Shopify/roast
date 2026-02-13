# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Opencode < Provider
          class OpencodeInvocation
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

            #: Result
            attr_reader :result

            #: (Agent::Config, Agent::Input) -> void
            def initialize(config, input)
              @start_time = nil
              @end_time = nil
              @model = config.valid_model #: String?
              @result = Result.new #: Result
              @prompt = input.valid_prompt! #: String
              @working_directory = config.valid_working_directory #: Pathname?
            end

            #: () -> void
            def run!
              _stdout, stderr, status = CommandRunner.execute(
                [
                  ENV["ROAST_OPENCODE_PREFIX"],
                  "opencode",
                  "--model=#{@model}",
                  "--format=json",
                  "run",
                ].compact,
                working_directory: @working_directory,
                stdin_content: @prompt,
                stdout_handler: lambda { |line| handle_stdout(line) },
              )

              if status.success?
                @completed = true
                # @result.response = stdout
                @result.success = true
              else
                @failed = true
                @result.success = false
                @result.response += "\n" unless @result.response.blank? || @result.response.ends_with?("\n")
                @result.response += stderr
              end
            end

            private

            #: (String) -> void
            def handle_stdout(line)
              message = Message.from_json(line)

              case message.type
              when :step_start
                @start_time = message.timestamp
              when :text
                @result.response = message.part["text"]
              when :step_finish
                @end_time = message.timestamp
                @result.stats = Stats.new
                @result.stats&.duration_ms = @end_time - @start_time
                @result.stats&.usage = Usage.new.tap do |u|
                  u.cost_usd = message.part["cost"]
                  u.input_tokens = message.part["tokens"]["input"] + message.part["tokens"]["cache"]["read"]
                  u.output_tokens = message.part["tokens"]["output"] + message.part["tokens"]["cache"]["write"]
                end
              end
            end
          end
        end
      end
    end
  end
end
