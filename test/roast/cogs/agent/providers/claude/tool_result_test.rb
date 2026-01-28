# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ToolResultTest < ActiveSupport::TestCase
            test "initialize with tool_use message" do
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { name: "bash", input: { description: "List files" } },
              )
              tool_result = ToolResult.new(
                tool_use: tool_use_message,
                content: "file1.txt\nfile2.txt",
                is_error: false,
              )

              assert_equal :bash, tool_result.tool_name
              assert_equal "List files", tool_result.tool_use_description
              assert_equal "file1.txt\nfile2.txt", tool_result.content
              refute tool_result.is_error
            end

            test "initialize with nil tool_use" do
              tool_result = ToolResult.new(
                tool_use: nil,
                content: "some content",
                is_error: false,
              )

              assert_equal :unknown, tool_result.tool_name
              assert_nil tool_result.tool_use_description
            end

            test "initialize with tool_use without description" do
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { name: "custom", input: {} },
              )
              tool_result = ToolResult.new(
                tool_use: tool_use_message,
                content: "result",
                is_error: false,
              )

              assert_nil tool_result.tool_use_description
            end

            test "initialize sets is_error flag" do
              tool_result = ToolResult.new(
                tool_use: nil,
                content: "error message",
                is_error: true,
              )

              assert tool_result.is_error
            end

            test "format calls format_unknown for unknown tool" do
              tool_result = ToolResult.new(
                tool_use: nil,
                content: "result content",
                is_error: false,
              )

              output = tool_result.format

              assert_match(/UNKNOWN \[unknown\]/, output)
              assert_match(/OK/, output)
              assert_match(/result content/, output)
            end

            test "format shows ERROR for error results" do
              tool_result = ToolResult.new(
                tool_use: nil,
                content: "error details",
                is_error: true,
              )

              output = tool_result.format

              assert_match(/ERROR/, output)
              assert_match(/error details/, output)
            end

            test "format includes description when present" do
              tool_use_message = Messages::ToolUseMessage.new(
                type: :tool_use,
                hash: { name: "bash", input: { description: "Run command" } },
              )
              tool_result = ToolResult.new(
                tool_use: tool_use_message,
                content: "output",
                is_error: false,
              )

              output = tool_result.format

              assert_match(/Run command/, output)
            end
          end
        end
      end
    end
  end
end
