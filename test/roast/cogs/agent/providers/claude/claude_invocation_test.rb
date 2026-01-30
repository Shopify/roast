# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ClaudeInvocationTest < ActiveSupport::TestCase
            def setup
              @config = Agent::Config.new
              @config.no_show_progress!
              @input = Agent::Input.new
              @input.prompt = "Test prompt"
              @invocation = ClaudeInvocation.new(@config, @input)
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

            test "Context#tool_use returns nil when tool_use_id is nil" do
              context = ClaudeInvocation::Context.new

              assert_nil context.tool_use(nil)
            end

            test "Context#tool_use returns nil for unknown tool_use_id" do
              context = ClaudeInvocation::Context.new

              assert_nil context.tool_use("unknown_id")
            end

            test "Context#tool_use returns stored ToolUseMessage for known id" do
              context = ClaudeInvocation::Context.new
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { id: "test_id", name: "bash", input: { command: "ls" } },
              )
              context.add_tool_use(tool_use_message)

              result = context.tool_use("test_id")

              assert_equal tool_use_message, result
            end

            test "Context#add_tool_use ignores message with nil id" do
              context = ClaudeInvocation::Context.new
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { name: "bash", input: { command: "ls" } },
              )
              context.add_tool_use(tool_use_message)

              assert_nil context.tool_use(nil)
            end

            test "Result initializes with empty response and success false" do
              result = ClaudeInvocation::Result.new

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

            test "result raises ClaudeNotStartedError when not started" do
              assert_raises(ClaudeInvocation::ClaudeNotStartedError) do
                @invocation.result
              end
            end

            test "result raises ClaudeFailedError when failed" do
              CommandRunner.stub(:execute, ["", "Error message", failure_status]) do
                @invocation.run!
              end

              assert_raises(ClaudeInvocation::ClaudeFailedError) do
                @invocation.result
              end
            end

            test "result raises ClaudeNotCompletedError when started but not completed" do
              CommandRunner.stub(:execute, ->(*) {
                assert_raises(ClaudeInvocation::ClaudeNotCompletedError) do
                  @invocation.result
                end
                ["", "", success_status]
              }) do
                @invocation.run!
              end
            end

            test "run! raises ClaudeAlreadyStartedError when called twice" do
              CommandRunner.stub(:execute, ["", "", success_status]) do
                @invocation.run!
                assert_raises(ClaudeInvocation::ClaudeAlreadyStartedError) do
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
              assert_kind_of ClaudeInvocation::Result, result
            end

            test "command_line uses default claude command" do
              command = @invocation.send(:command_line)

              assert_equal "claude", command.first
              assert_includes command, "-p"
              assert_includes command, "--verbose"
              assert_includes command, "--output-format"
              assert_includes command, "stream-json"
            end

            test "command_line uses custom command when configured as string" do
              @config.command("custom-claude --flag")
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_equal "custom-claude", command.first
              assert_includes command, "--flag"
            end

            test "command_line uses custom command when configured as array" do
              @config.command(["my-claude", "--opt"])
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_equal "my-claude", command.first
              assert_includes command, "--opt"
            end

            test "command_line includes model when configured" do
              @config.model("claude-opus-4-5-20251101")
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              model_index = command.index("--model")
              assert model_index
              assert_equal "claude-opus-4-5-20251101", command[model_index + 1]
            end

            test "command_line includes replace_system_prompt when configured" do
              @config.replace_system_prompt("Custom system prompt")
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              prompt_index = command.index("--system-prompt")
              assert prompt_index
              assert_equal "Custom system prompt", command[prompt_index + 1]
            end

            test "command_line includes append_system_prompt when configured" do
              @config.append_system_prompt("Additional instructions")
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              prompt_index = command.index("--append-system-prompt")
              assert prompt_index
              assert_equal "Additional instructions", command[prompt_index + 1]
            end

            test "command_line includes session flags when session is set" do
              @input.session = "session_123"
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              assert_includes command, "--fork-session"
              assert_includes command, "--resume"
              resume_index = command.index("--resume")
              assert_equal "session_123", command[resume_index + 1]
            end

            test "command_line includes dangerously-skip-permissions by default" do
              command = @invocation.send(:command_line)

              assert_includes command, "--dangerously-skip-permissions"
            end

            test "command_line omits dangerously-skip-permissions when permissions applied" do
              @config.apply_permissions!
              invocation = ClaudeInvocation.new(@config, @input)

              command = invocation.send(:command_line)

              refute_includes command, "--dangerously-skip-permissions"
            end

            test "handle_message processes ResultMessage and sets response" do
              result_message = Messages::ResultMessage.new(
                type: :result,
                hash: { result: "Test response", subtype: "success" },
              )

              @invocation.send(:handle_message, result_message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "Test response", internal_result.response
              assert internal_result.success
            end

            test "handle_message processes ToolUseMessage and stores in context" do
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { id: "tool_123", name: "bash", input: { command: "ls" } },
              )

              @invocation.send(:handle_message, tool_use_message)

              context = @invocation.instance_variable_get(:@context)
              assert_equal tool_use_message, context.tool_use("tool_123")
            end

            test "handle_message processes AssistantMessage recursively" do
              text_hash = { type: :text, text: "Hello" }
              assistant_message = Messages::AssistantMessage.new(
                type: :assistant,
                hash: { message: { content: [text_hash] } },
              )

              assert_nothing_raised do
                @invocation.send(:handle_message, assistant_message)
              end
            end

            test "handle_message captures session_id when present" do
              message = Messages::TextMessage.new(
                type: :text,
                hash: { text: "Hello", session_id: "new_session" },
              )

              @invocation.send(:handle_message, message)

              internal_result = @invocation.instance_variable_get(:@result)
              assert_equal "new_session", internal_result.session
            end
          end
        end
      end
    end
  end
end
