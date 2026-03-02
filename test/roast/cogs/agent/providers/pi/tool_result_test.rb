# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolResultTest < ActiveSupport::TestCase
            test "extracts tool_name from tool_call" do
              tool_call = Messages::ToolCallEndMessage.new(
                type: :toolcall_end,
                hash: {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { id: "1", name: "bash", arguments: {} },
                  },
                },
              )

              tool_result = ToolResult.new(tool_call:, content: "output", is_error: false)

              assert_equal :bash, tool_result.tool_name
            end

            test "uses :unknown when tool_call is nil" do
              tool_result = ToolResult.new(tool_call: nil, content: "output", is_error: false)

              assert_equal :unknown, tool_result.tool_name
            end

            test "format shows error status" do
              tool_result = ToolResult.new(tool_call: nil, content: "error msg", is_error: true)

              formatted = tool_result.format
              assert_match(/ERROR/, formatted)
              assert_match(/error msg/, formatted)
            end

            test "format shows OK status" do
              tool_result = ToolResult.new(tool_call: nil, content: "success", is_error: false)

              formatted = tool_result.format
              assert_match(/OK/, formatted)
            end
          end
        end
      end
    end
  end
end
