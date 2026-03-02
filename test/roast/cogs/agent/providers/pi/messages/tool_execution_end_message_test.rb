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
            end
          end
        end
      end
    end
  end
end
