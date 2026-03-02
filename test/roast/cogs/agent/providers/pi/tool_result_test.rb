# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolResultTest < ActiveSupport::TestCase
            test "initialize sets attributes" do
              result = ToolResult.new(tool_name: "bash", content: "output", is_error: false)

              assert_equal "bash", result.tool_name
              assert_equal "output", result.content
              refute result.is_error
            end

            test "format shows OK status for successful results" do
              result = ToolResult.new(tool_name: "read", content: "file contents", is_error: false)

              output = result.format

              assert_includes output, "RESULT [read]"
              assert_includes output, "OK"
              assert_includes output, "file contents"
            end

            test "format shows ERROR status for error results" do
              result = ToolResult.new(tool_name: "bash", content: "command not found", is_error: true)

              output = result.format

              assert_includes output, "RESULT [bash]"
              assert_includes output, "ERROR"
              assert_includes output, "command not found"
            end

            test "format truncates long content" do
              long_content = "x" * 300
              result = ToolResult.new(tool_name: "read", content: long_content, is_error: false)

              output = result.format

              assert_operator output.length, :<, 300
              assert_includes output, "..."
            end

            test "format handles nil content" do
              result = ToolResult.new(tool_name: "bash", content: nil, is_error: false)

              output = result.format

              assert_includes output, "RESULT [bash] OK"
              refute_includes output, ":"  # No content preview separator
            end

            test "format handles empty content" do
              result = ToolResult.new(tool_name: "bash", content: "", is_error: false)

              output = result.format

              assert_includes output, "RESULT [bash] OK"
            end

            test "format collapses whitespace in content preview" do
              result = ToolResult.new(tool_name: "read", content: "line 1\n  line 2\n\tline 3", is_error: false)

              output = result.format

              assert_includes output, "line 1 line 2 line 3"
            end
          end
        end
      end
    end
  end
end
