# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class PiInvocationTest < ActiveSupport::TestCase
            def setup
              @config = Agent::Config.new
              @config.no_show_progress!
              @input = Agent::Input.new
              @input.prompt = "Test prompt"
              @invocation = PiInvocation.new(@config, @input)
            end

            def success_status
              mock = Minitest::Mock.new
              mock.expect(:success?, true)
              mock
            end

            def failure_status
              mock = Minitest::Mock.new
              mock.expect(:success?, false)
              mock
            end

            # Result tests

            test "Result initializes with empty response and success false" do
              result = PiInvocation::Result.new

              assert_equal "", result.response
              refute result.success
              assert_nil result.session
              assert_nil result.stats
            end

            # Lifecycle state tests

            test "started? returns false initially" do
              refute @invocation.started?
            end

            test "completed? returns false initially" do
              refute @invocation.completed?
            end

            test "failed? returns false initially" do
              refute @invocation.failed?
            end

            test "running? returns false when not started" do
              refute @invocation.running?
            end

            test "result raises PiNotStartedError when not started" do
              assert_raises(PiInvocation::PiNotStartedError) do
                @invocation.result
              end
            end

            test "result raises PiFailedError when failed" do
              CommandRunner.stub(:execute, ["", "Error message", failure_status]) do
                @invocation.run!
              end

              assert_raises(PiInvocation::PiFailedError) do
                @invocation.result
              end
            end

            test "result raises PiNotCompletedError when started but not completed" do
              CommandRunner.stub(:execute, ->(*) {
                assert_raises(PiInvocation::PiNotCompletedError) do
                  @invocation.result
                end
                ["", "", success_status]
              }) do
                @invocation.run!
              end
            end

            test "run! raises PiAlreadyStartedError when called twice" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
                assert_raises(PiInvocation::PiAlreadyStartedError) do
                  @invocation.run!
                end
              end
            end

            test "run! sets started to true" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
              end

              assert @invocation.started?
            end

            test "run! sets completed to true on successful execution" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
              end

              assert @invocation.completed?
              refute @invocation.failed?
            end

            test "run! sets failed to true on unsuccessful execution" do
              CommandRunner.stub(:execute, ["", "Error message", failure_status]) do
                @invocation.run!
              end

              assert @invocation.failed?
              refute @invocation.completed?
            end

            test "running? returns true during execution" do
              CommandRunner.stub(:execute, ->(*) {
                assert @invocation.started?
                assert @invocation.running?
                ["", "", success_status]
              }) do
                @invocation.run!
              end

              refute @invocation.running?
            end

            test "result returns Result object when completed successfully" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
              end

              result = @invocation.result
              assert_kind_of PiInvocation::Result, result
            end

            # Command line construction tests

            test "command_line uses default pi command" do
              command = @invocation.send(:command_line)

              assert_equal "pi", command.first
              assert_includes command, "-p"
              assert_includes command, "--mode"
              assert_includes command, "json"
            end

            test "command_line uses custom command when configured as string" do
              @config.command("custom-pi --flag")
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_equal "custom-pi", command.first
              assert_includes command, "--flag"
            end

            test "command_line uses custom command when configured as array" do
              @config.command(["my-pi", "--opt"])
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_equal "my-pi", command.first
              assert_includes command, "--opt"
            end

            test "command_line includes model when configured" do
              @config.model("claude-sonnet-4-20250514")
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              model_index = command.index("--model")
              assert model_index
              assert_equal "claude-sonnet-4-20250514", command[model_index + 1]
            end

            test "command_line includes replace_system_prompt when configured" do
              @config.replace_system_prompt("Custom system prompt")
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              prompt_index = command.index("--system-prompt")
              assert prompt_index
              assert_equal "Custom system prompt", command[prompt_index + 1]
            end

            test "command_line includes append_system_prompt when configured" do
              @config.append_system_prompt("Additional instructions")
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              prompt_index = command.index("--append-system-prompt")
              assert prompt_index
              assert_equal "Additional instructions", command[prompt_index + 1]
            end

            test "command_line includes session flag when session is set" do
              @input.session = "path/to/session.jsonl"
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_includes command, "--session"
              session_index = command.index("--session")
              assert_equal "path/to/session.jsonl", command[session_index + 1]
            end

            test "command_line omits session flag when no session" do
              command = @invocation.send(:command_line)

              refute_includes command, "--session"
            end

            test "command_line does not include permissions flags" do
              # Pi does not have a --dangerously-skip-permissions equivalent
              command = @invocation.send(:command_line)

              refute_includes command, "--dangerously-skip-permissions"
            end

            # Message handling tests

            test "handle_message extracts session id from session message" do
              message = Messages::SessionMessage.new(
                type: "session",
                hash: { id: "abc-123", version: 3 },
              )

              @invocation.send(:handle_message, message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "abc-123", internal_result.session
            end

            test "handle_message extracts response from agent_end message" do
              message = Messages::AgentEndMessage.new(
                type: "agent_end",
                hash: {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                    { role: "assistant", content: [{ type: "text", text: "Hi there!" }] },
                  ],
                },
              )

              @invocation.send(:handle_message, message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Hi there!", internal_result.response
              assert internal_result.success
            end

            test "handle_message extracts response from last assistant message in agent_end" do
              message = Messages::AgentEndMessage.new(
                type: "agent_end",
                hash: {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                    { role: "assistant", content: [{ type: "toolCall", name: "read", arguments: {} }] },
                    { role: "assistant", content: [{ type: "text", text: "Final response" }] },
                  ],
                },
              )

              @invocation.send(:handle_message, message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Final response", internal_result.response
            end

            test "handle_message accumulates turn stats" do
              message = Messages::TurnEndMessage.new(
                type: "turn_end",
                hash: {
                  message: {
                    role: "assistant",
                    model: "claude-sonnet-4-20250514",
                    usage: {
                      input: 100,
                      output: 50,
                      cost: { total: 0.001 },
                    },
                  },
                },
              )

              @invocation.send(:handle_message, message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal 1, internal_result.stats.num_turns
              assert_equal 100, internal_result.stats.usage.input_tokens
              assert_equal 50, internal_result.stats.usage.output_tokens
              assert_in_delta 0.001, internal_result.stats.usage.cost_usd
              assert_equal 100, internal_result.stats.model_usage["claude-sonnet-4-20250514"].input_tokens
              assert_equal 50, internal_result.stats.model_usage["claude-sonnet-4-20250514"].output_tokens
            end

            test "handle_message accumulates stats across multiple turns" do
              turn1 = Messages::TurnEndMessage.new(
                type: "turn_end",
                hash: {
                  message: {
                    role: "assistant",
                    model: "claude-sonnet-4-20250514",
                    usage: { input: 100, output: 50, cost: { total: 0.001 } },
                  },
                },
              )
              turn2 = Messages::TurnEndMessage.new(
                type: "turn_end",
                hash: {
                  message: {
                    role: "assistant",
                    model: "claude-sonnet-4-20250514",
                    usage: { input: 200, output: 75, cost: { total: 0.002 } },
                  },
                },
              )

              @invocation.send(:handle_message, turn1)
              @invocation.send(:handle_message, turn2)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal 2, internal_result.stats.num_turns
              assert_equal 300, internal_result.stats.usage.input_tokens
              assert_equal 125, internal_result.stats.usage.output_tokens
              assert_in_delta 0.003, internal_result.stats.usage.cost_usd
            end

            # Duration tracking tests

            test "run! records duration_ms on successful completion" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
              end

              result = @invocation.result
              assert_not_nil result.stats
              assert_not_nil result.stats.duration_ms
              assert_operator result.stats.duration_ms, :>=, 0
            end

            test "run! does not record duration on failure" do
              CommandRunner.stub(:execute, ["", "Error", failure_status]) do
                @invocation.run!
              end

              internal_result = @invocation.instance_variable_get(:@result)
              assert_nil internal_result.stats
            end

            # Fixture-based integration tests

            test "simple response fixture: extracts response, session, and stats" do
              use_command_runner_fixture(
                "agent_transcripts/pi_simple_response",
                expected_args: ["pi", "-p", "--mode", "json"],
                expected_stdin_content: "Test prompt",
              )

              @invocation.run!
              result = @invocation.result

              assert_equal "The capital of France is Paris.", result.response
              assert result.success
              assert_equal "test-session-abc-123", result.session
            end

            test "simple response fixture: records turn count" do
              use_command_runner_fixture("agent_transcripts/pi_simple_response")

              @invocation.run!
              result = @invocation.result

              assert_equal 1, result.stats.num_turns
            end

            test "simple response fixture: records token usage per model" do
              use_command_runner_fixture("agent_transcripts/pi_simple_response")

              @invocation.run!
              result = @invocation.result

              model_usage = result.stats.model_usage["claude-sonnet-4-20250514"]
              assert_not_nil model_usage
              assert_equal 5, model_usage.input_tokens
              assert_equal 10, model_usage.output_tokens
              assert_in_delta 0.006525, model_usage.cost_usd
            end

            test "simple response fixture: records aggregate token usage" do
              use_command_runner_fixture("agent_transcripts/pi_simple_response")

              @invocation.run!
              result = @invocation.result

              assert_equal 5, result.stats.usage.input_tokens
              assert_equal 10, result.stats.usage.output_tokens
              assert_in_delta 0.006525, result.stats.usage.cost_usd
            end

            test "simple response fixture: records duration" do
              use_command_runner_fixture("agent_transcripts/pi_simple_response")

              @invocation.run!
              result = @invocation.result

              assert_not_nil result.stats.duration_ms
              assert_operator result.stats.duration_ms, :>=, 0
            end

            test "tool use fixture: extracts final text response after tool use" do
              use_command_runner_fixture("agent_transcripts/pi_tool_use_response")

              @invocation.run!
              result = @invocation.result

              assert_equal "The file contains: Hello, World!", result.response
              assert result.success
              assert_equal "test-session-tool-456", result.session
            end

            test "tool use fixture: records two turns" do
              use_command_runner_fixture("agent_transcripts/pi_tool_use_response")

              @invocation.run!
              result = @invocation.result

              assert_equal 2, result.stats.num_turns
            end

            test "tool use fixture: accumulates token usage across turns" do
              use_command_runner_fixture("agent_transcripts/pi_tool_use_response")

              @invocation.run!
              result = @invocation.result

              # Turn 1: input=5, output=20; Turn 2: input=25, output=12
              assert_equal 30, result.stats.usage.input_tokens
              assert_equal 32, result.stats.usage.output_tokens
            end

            test "tool use fixture: accumulates cost across turns" do
              use_command_runner_fixture("agent_transcripts/pi_tool_use_response")

              @invocation.run!
              result = @invocation.result

              # Turn 1: 0.013025; Turn 2: 0.00605
              assert_in_delta 0.019075, result.stats.usage.cost_usd
            end

            test "tool use fixture: accumulates per-model usage across turns" do
              use_command_runner_fixture("agent_transcripts/pi_tool_use_response")

              @invocation.run!
              result = @invocation.result

              model_usage = result.stats.model_usage["claude-sonnet-4-20250514"]
              assert_not_nil model_usage
              assert_equal 30, model_usage.input_tokens
              assert_equal 32, model_usage.output_tokens
              assert_in_delta 0.019075, model_usage.cost_usd
            end

            test "failure appends stderr to response" do
              CommandRunner.stub(:execute, ["", "pi: command failed\ndetails here", failure_status]) do
                @invocation.run!
              end

              internal_result = @invocation.instance_variable_get(:@result)
              assert_includes internal_result.response, "pi: command failed"
              assert_includes internal_result.response, "details here"
            end

            test "stats to_s produces readable output" do
              use_command_runner_fixture("agent_transcripts/pi_simple_response")

              @invocation.run!
              result = @invocation.result
              stats_string = result.stats.to_s

              assert_includes stats_string, "Turns:"
              assert_includes stats_string, "Duration:"
              assert_includes stats_string, "Cost (USD):"
              assert_includes stats_string, "Tokens (claude-sonnet-4-20250514):"
            end
          end
        end
      end
    end
  end
end
