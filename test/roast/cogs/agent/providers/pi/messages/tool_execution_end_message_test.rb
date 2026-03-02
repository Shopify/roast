# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolExecutionEndMessageTest < ActiveSupport::TestCase
              test "extracts tool execution fields" do
                message = ToolExecutionEndMessage.new(
                  type: :tool_execution_end,
                  hash: {
                    toolCallId: "tool_123",
                    toolName: "bash",
                    result: { content: [{ type: "text", text: "output here" }] },
                    isError: false,
                  },
                )

                assert_equal "tool_123", message.tool_call_id
                assert_equal "bash", message.tool_name
                refute message.is_error
              end

              test "extracts text content from result" do
                message = ToolExecutionEndMessage.new(
                  type: :tool_execution_end,
                  hash: {
                    toolCallId: "tool_1",
                    toolName: "bash",
                    result: {
                      content: [
                        { type: "text", text: "line 1\n" },
                        { type: "text", text: "line 2\n" },
                      ],
                    },
                    isError: false,
                  },
                )

                content = message.send(:extract_content)
                assert_equal "line 1\nline 2\n", content
              end

              test "is_error defaults to false" do
                message = ToolExecutionEndMessage.new(
                  type: :tool_execution_end,
                  hash: {
                    toolCallId: "tool_1",
                    toolName: "bash",
                    result: {},
                  },
                )

                refute message.is_error
              end

              test "format uses context to look up tool call" do
                # First, register a tool call in context
                tool_call = ToolCallEndMessage.new(
                  type: :toolcall_end,
                  hash: {
                    assistantMessageEvent: {
                      type: "toolcall_end",
                      toolCall: { id: "tool_1", name: "bash", arguments: { command: "ls" } },
                    },
                  },
                )
                context = PiInvocation::Context.new
                context.add_tool_call(tool_call)

                message = ToolExecutionEndMessage.new(
                  type: :tool_execution_end,
                  hash: {
                    toolCallId: "tool_1",
                    toolName: "bash",
                    result: { content: [{ type: "text", text: "file.txt\n" }] },
                    isError: false,
                  },
                )

                formatted = message.format(context)
                assert_kind_of String, formatted
              end
            end
          end
        end
      end
    end
  end
end
