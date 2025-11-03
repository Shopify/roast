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
              end

              #: (Agent::Config, Agent::Input) -> void
              def initialize(config, input)
                @model = config.valid_model
                @append_system_prompt = config.valid_initial_prompt
                @apply_permissions = config.apply_permissions?
                @working_directory = config.valid_working_directory
                @prompt = input.valid_prompt!
              end

              #: () -> void
              def run!
                raise ClaudeAlreadyStartedError if started?

                @started = true
                puts "Running Claude: #{command_line}"
                puts "Providing Standard Input: #{@prompt}"

                stdout, stderr, status = CommandRunner.execute(
                  command_line,
                  working_directory: @working_directory,
                  stdin_content: @prompt,
                )

                unless status.success?
                  raise "Claude command failed: #{stderr}"
                end

                @result = Result.new
                @result.response = stdout.strip
              rescue StandardError => e
                @failed = true
                raise e
              end

              #: () -> bool
              def started?
                @started ||= false
              end

              #: () -> bool
              def running?
                @started && !@failed && @result.present?
              end

              #: () -> bool
              def completed?
                @result.present?
              end

              #: () -> bool
              def failed?
                @failed ||= false
              end

              #: () -> Result
              def result
                raise ClaudeNotStartedError unless started?
                raise ClaudeFailedError if failed?
                raise ClaudeNotCompletedError unless @result.present?

                @result
              end

              private

              #: () -> Array[String]
              def command_line
                command = ["claude", "-p"]
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
