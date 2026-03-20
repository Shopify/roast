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

            test "Context#tool_call returns nil when tool_call_id is nil" do
              context = PiInvocation::Context.new
              assert_nil context.tool_call(nil)
            end

            test "Context#tool_call returns nil for unknown tool_call_id" do
              context = PiInvocation::Context.new
              assert_nil context.tool_call("unknown_id")
            end

            test "Context#tool_call returns stored ToolCallMessage for known id" do
              context = PiInvocation::Context.new
              tool_call_msg = Messages::ToolCallMessage.new(
                id: "test_id",
                name: "bash",
                arguments: { command: "ls" },
              )
              context.add_tool_call(tool_call_msg)

              result = context.tool_call("test_id")
              assert_equal tool_call_msg, result
            end

            test "Context#add_tool_call ignores message with nil id" do
              context = PiInvocation::Context.new
              tool_call_msg = Messages::ToolCallMessage.new(
                id: nil,
                name: "bash",
                arguments: { command: "ls" },
              )
              context.add_tool_call(tool_call_msg)
              assert_nil context.tool_call(nil)
            end

            test "Result initializes with empty response and success false" do
              result = PiInvocation::Result.new
              assert_equal "", result.response
              refute result.success
              assert_nil result.session
              assert_nil result.stats
            end

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

            test "command_line uses default pi command" do
              command = @invocation.send(:command_line)
              assert_equal "pi", command.first
              assert_includes command, "--mode"
              assert_includes command, "json"
              assert_includes command, "-p"
              assert_includes command, "--no-session"
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
              @config.model("anthropic/claude-sonnet-4-20250514")
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)
              model_index = command.index("--model")
              assert model_index
              assert_equal "anthropic/claude-sonnet-4-20250514", command[model_index + 1]
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

            test "command_line includes fork flag when session is set" do
              @input.session = "93b0c56b-b6a9-4b33-8dff-ce0fabceae6d"
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)
              assert_includes command, "--fork"
              fork_index = command.index("--fork")
              assert_equal "93b0c56b-b6a9-4b33-8dff-ce0fabceae6d", command[fork_index + 1]
              refute_includes command, "--no-session"
            end

            test "command_line includes --no-session when no session is set" do
              invocation = PiInvocation.new(@config, @input)

              command = invocation.send(:command_line)
              assert_includes command, "--no-session"
              refute_includes command, "--fork"
            end

            test "handle_message processes session event and sets session id" do
              data = { type: "session", id: "test-session-uuid", version: 3 }

              Event.expects(:<<).with { |payload| payload[:debug] == "New Pi Session ID: test-session-uuid" }
              @invocation.send(:handle_message, data)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "test-session-uuid", internal_result.session
            end

            test "handle_message processes turn_start and increments turn count" do
              @invocation.send(:handle_message, { type: "turn_start" })
              @invocation.send(:handle_message, { type: "turn_start" })

              num_turns = @invocation.instance_variable_get(:@num_turns)
              assert_equal 2, num_turns
            end

            test "handle_message processes text_end and sets response" do
              data = {
                type: "message_update",
                assistantMessageEvent: {
                  type: "text_end",
                  content: "Hello! How can I help?",
                },
              }

              @invocation.send(:handle_message, data)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Hello! How can I help?", internal_result.response
            end

            test "handle_message processes agent_end and extracts final response" do
              data = {
                type: "agent_end",
                messages: [
                  { role: "user", content: [{ type: "text", text: "hello" }] },
                  { role: "assistant", content: [{ type: "text", text: "Hi there!" }] },
                ],
              }

              @invocation.send(:handle_message, data)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Hi there!", internal_result.response
            end

            test "handle_message processes message_end with assistant usage" do
              data = {
                type: "message_end",
                message: {
                  role: "assistant",
                  model: "claude-sonnet-4-20250514",
                  content: [{ type: "text", text: "Response text" }],
                  usage: {
                    input: 100,
                    output: 50,
                    cacheRead: 200,
                    cacheWrite: 50,
                    totalTokens: 400,
                    cost: { input: 0.001, output: 0.002, total: 0.003 },
                  },
                },
              }

              @invocation.send(:handle_message, data)

              acc = @invocation.instance_variable_get(:@model_usage_accumulator)
              assert acc.key?("claude-sonnet-4-20250514")
              assert_equal 100, acc["claude-sonnet-4-20250514"][:input]
              assert_equal 50, acc["claude-sonnet-4-20250514"][:output]
            end

            test "handle_message processes toolcall_end and stores in context" do
              data = {
                type: "message_update",
                assistantMessageEvent: {
                  type: "toolcall_end",
                  toolCall: {
                    id: "tool_123",
                    name: "bash",
                    arguments: { command: "ls -la" },
                  },
                },
              }

              @invocation.send(:handle_message, data)

              context = @invocation.instance_variable_get(:@context)
              assert_equal "bash", context.tool_call("tool_123").name
            end

            test "finalize_stats creates proper stats object" do
              # Simulate accumulated usage
              acc = @invocation.instance_variable_get(:@model_usage_accumulator)
              acc["claude-sonnet-4-20250514"] = { input: 100, output: 50, cache_read: 200, cache_write: 50, cost: 0.003 }
              @invocation.instance_variable_set(:@num_turns, 3)
              @invocation.instance_variable_set(:@total_cost, 0.003)

              @invocation.send(:finalize_stats!)

              result = @invocation.instance_variable_get(:@result)
              stats = result.stats
              assert_equal 3, stats.num_turns
              assert_equal 100, stats.usage.input_tokens
              assert_equal 50, stats.usage.output_tokens
              assert_in_delta 0.003, stats.usage.cost_usd
              assert stats.model_usage.key?("claude-sonnet-4-20250514")
            end

            test "does not emit duplicate session events" do
              data = { type: "session", id: "same-session" }

              Event.expects(:<<).once
              @invocation.send(:handle_message, data)
              @invocation.send(:handle_message, data)
            end

            test "emits new session event when session changes" do
              first = { type: "session", id: "session-1" }
              second = { type: "session", id: "session-2" }

              Event.expects(:<<).twice
              @invocation.send(:handle_message, first)
              @invocation.send(:handle_message, second)
            end
          end
        end
      end
    end
  end
end
