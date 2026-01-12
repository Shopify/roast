# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    module Cogs
      class Agent
        module Providers
          class CodexTest < ActiveSupport::TestCase
            test "VALID_PROVIDERS includes codex" do
              assert_includes Agent::Config::VALID_PROVIDERS, :codex
            end

            test "config.valid_provider! returns codex when configured" do
              config = Agent::Config.new
              config.provider(:codex)
              assert_equal :codex, config.valid_provider!
            end

            test "config.valid_provider! raises for invalid provider" do
              config = Agent::Config.new
              config.provider(:invalid_provider)
              assert_raises(ArgumentError) { config.valid_provider! }
            end

            test "CodexInvocation builds correct command line with defaults" do
              config = Agent::Config.new
              config.provider(:codex)

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "codex"
              assert_includes command, "exec"
              assert_includes command, "Test prompt"
              assert_includes command, "--full-auto"
            end

            test "CodexInvocation builds command with custom model" do
              config = Agent::Config.new
              config.provider(:codex)
              config.model("gpt-4")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "--model"
              model_index = command.index("--model")
              assert_equal "gpt-4", command[model_index + 1]
            end

            test "CodexInvocation builds command with permissions applied" do
              config = Agent::Config.new
              config.provider(:codex)
              config.apply_permissions!

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              refute_includes command, "--full-auto"
            end

            test "CodexInvocation builds command with system prompt replacement" do
              config = Agent::Config.new
              config.provider(:codex)
              config.replace_system_prompt("Custom system prompt")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "--instructions"
              instructions_index = command.index("--instructions")
              assert_equal "Custom system prompt", command[instructions_index + 1]
            end

            test "CodexInvocation builds command with custom base command" do
              config = Agent::Config.new
              config.provider(:codex)
              config.command("/usr/local/bin/codex")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_equal "/usr/local/bin/codex", command.first
            end

            test "CodexInvocation builds command with array base command" do
              config = Agent::Config.new
              config.provider(:codex)
              config.command(["shadowenv", "exec", "--", "codex"])

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_equal ["shadowenv", "exec", "--", "codex"], command[0..3]
            end

            test "CodexInvocation.result raises when not started" do
              config = Agent::Config.new
              config.provider(:codex)

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Codex::CodexInvocation.new(config, input)
              assert_raises(Codex::CodexInvocation::CodexNotStartedError) { invocation.result }
            end

            test "Codex provider can be instantiated" do
              config = Agent::Config.new
              config.provider(:codex)

              provider = Codex.new(config)
              assert_instance_of Codex, provider
            end

            test "Agent creates Codex provider when configured" do
              config = Agent::Config.new
              config.provider(:codex)

              agent = Agent.allocate
              agent.instance_variable_set(:@config, config)

              # Access the private provider method
              provider = agent.send(:provider)
              assert_instance_of Codex, provider
            end
          end
        end
      end
    end
  end
end
