# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    module Cogs
      class Agent
        module Providers
          class OpencodeTest < ActiveSupport::TestCase
            test "VALID_PROVIDERS includes opencode" do
              assert_includes Agent::Config::VALID_PROVIDERS, :opencode
            end

            test "config.valid_provider! returns opencode when configured" do
              config = Agent::Config.new
              config.provider(:opencode)
              assert_equal :opencode, config.valid_provider!
            end

            test "OpencodeInvocation builds correct command line with defaults" do
              config = Agent::Config.new
              config.provider(:opencode)

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "opencode"
              assert_includes command, "run"
              assert_includes command, "Test prompt"
            end

            test "OpencodeInvocation builds command with custom model" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.model("shopify-google/gemini-3-pro-preview")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "--model"
              model_index = command.index("--model")
              assert_equal "shopify-google/gemini-3-pro-preview", command[model_index + 1]
            end

            test "OpencodeInvocation builds command with system prompt replacement" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.replace_system_prompt("Custom system prompt")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_includes command, "--system"
              system_index = command.index("--system")
              assert_equal "Custom system prompt", command[system_index + 1]
            end

            test "OpencodeInvocation builds command with custom base command" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.command("/usr/local/bin/opencode")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_equal "/usr/local/bin/opencode", command.first
            end

            test "OpencodeInvocation builds command with array base command" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.command(["shadowenv", "exec", "--", "opencode"])

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_equal ["shadowenv", "exec", "--", "opencode"], command[0..3]
            end

            test "OpencodeInvocation.result raises when not started" do
              config = Agent::Config.new
              config.provider(:opencode)

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              assert_raises(Opencode::OpencodeInvocation::OpencodeNotStartedError) { invocation.result }
            end

            test "Opencode provider can be instantiated" do
              config = Agent::Config.new
              config.provider(:opencode)

              provider = Opencode.new(config)
              assert_instance_of Opencode, provider
            end

            test "Agent creates Opencode provider when configured" do
              config = Agent::Config.new
              config.provider(:opencode)

              agent = Agent.allocate
              agent.instance_variable_set(:@config, config)

              # Access the private provider method
              provider = agent.send(:provider)
              assert_instance_of Opencode, provider
            end

            test "OpencodeInvocation does not add run if already present in command" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.command(["opencode", "run"])

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              # Count occurrences of "run"
              run_count = command.count("run")
              assert_equal 1, run_count, "Expected exactly one 'run' in command, got #{run_count}"
            end

            test "OpencodeInvocation places prompt at the end" do
              config = Agent::Config.new
              config.provider(:opencode)
              config.model("test-model")

              input = Agent::Input.new
              input.prompt = "Test prompt"

              invocation = Opencode::OpencodeInvocation.new(config, input)
              command = invocation.send(:command_line)

              assert_equal "Test prompt", command.last
            end
          end
        end
      end
    end
  end
end
