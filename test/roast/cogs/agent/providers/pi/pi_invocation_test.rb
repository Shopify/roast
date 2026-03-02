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
              @config.provider(:pi)
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

            # Context tests

            test "Context#tool_call returns nil when tool_call_id is nil" do
              context = PiInvocation::Context.new

              assert_nil context.tool_call(nil)
            end

            test "Context#tool_call returns nil for unknown tool_call_id" do
              context = PiInvocation::Context.new

              assert_nil context.tool_call("unknown_id")
            end

            test "Context#tool_call returns stored ToolCallEndMessage for known id" do
              context = PiInvocation::Context.new
              tool_call_message = Messages::ToolCallEndMessage.new(
                type: :toolcall_end,
                hash: {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { id: "test_id", name: "bash", arguments: { command: "ls" } },
                  },
                },
              )
              context.add_tool_call(tool_call_message)

              result = context.tool_call("test_id")

              assert_equal tool_call_message, result
            end

            test "Context#add_tool_call ignores message with nil id" do
              context = PiInvocation::Context.new
              tool_call_message = Messages::ToolCallEndMessage.new(
                type: :toolcall_end,
                hash: {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { name: "bash", arguments: { command: "ls" } },
                  },
                },
              )
              context.add_tool_call(tool_call_message)

              assert_nil context.tool_call(nil)
            end

            # Result tests

            test "Result initializes with empty response and success false" do
              result = PiInvocation::Result.new

              assert_equal "", result.response
              refute result.success
              assert_nil result.session
              assert_nil result.stats
            end

            # State tests

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

            # Command line tests

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
              @input.session = "/path/to/session.jsonl"
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_includes command, "--session"
              session_index = command.index("--session")
              assert_equal "/path/to/session.jsonl", command[session_index + 1]
            end

            test "command_line does not include session flag when session is blank" do
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              refute_includes command, "--session"
            end

            # Message handling tests

            test "handle_message processes SessionMessage and sets session" do
              session_message = Messages::SessionMessage.new(
                type: :session,
                hash: { id: "session_123", version: 3, timestamp: "2026-01-01", cwd: "/tmp" },
              )

              @invocation.send(:handle_message, session_message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "session_123", internal_result.session
            end

            test "handle_message processes AgentEndMessage and sets response" do
              agent_end_message = Messages::AgentEndMessage.new(
                type: :agent_end,
                hash: {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "hello" }] },
                    {
                      role: "assistant",
                      model: "claude-sonnet-4-20250514",
                      content: [{ type: "text", text: "Test response" }],
                      usage: { input: 10, output: 20, cost: { total: 0.001 } },
                    },
                  ],
                },
              )

              @invocation.send(:handle_message, agent_end_message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Test response", internal_result.response
              assert internal_result.success
              assert_not_nil internal_result.stats
            end

            test "handle_message processes TurnEndMessage and increments turn counter" do
              turn_end = Messages::TurnEndMessage.new(
                type: :turn_end,
                hash: { message: { role: "assistant" }, toolResults: [] },
              )

              @invocation.send(:handle_message, turn_end)
              @invocation.send(:handle_message, turn_end)

              assert_equal 2, @invocation.instance_variable_get(:@num_turns)
            end

            test "handle_message processes ToolCallEndMessage and stores in context" do
              tool_call_message = Messages::ToolCallEndMessage.new(
                type: :toolcall_end,
                hash: {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { id: "tool_123", name: "bash", arguments: { command: "ls" } },
                  },
                },
              )

              @invocation.send(:handle_message, tool_call_message)

              context = @invocation.instance_variable_get(:@context)
              assert_equal tool_call_message, context.tool_call("tool_123")
            end
          end
        end
      end
    end
  end
end
