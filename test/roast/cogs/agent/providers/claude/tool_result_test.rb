# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    module Agent::Providers
      class Claude::ToolResultTest < ActiveSupport::TestCase
        test "initialize with tool_use message" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: { description: "List files" } },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "file1.txt\nfile2.txt",
            is_error: false,
          )

          assert_equal :bash, tool_result.tool_name
          assert_equal "List files", tool_result.tool_use_description
          assert_equal({ description: "List files" }, tool_result.tool_use_input)
          assert_equal "file1.txt\nfile2.txt", tool_result.content
          refute tool_result.is_error
        end

        test "initialize with nil tool_use" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: "some content",
            is_error: false,
          )

          assert_equal :unknown, tool_result.tool_name
          assert_nil tool_result.tool_use_description
          assert_equal({}, tool_result.tool_use_input)
        end

        test "initialize with tool_use without description" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "custom", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "result",
            is_error: false,
          )

          assert_nil tool_result.tool_use_description
        end

        test "initialize sets is_error flag" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: "error message",
            is_error: true,
          )

          assert tool_result.is_error
        end

        test "format calls format_unknown for unknown tool" do
          tool_result = Claude::ToolResult.new(
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
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: "error details",
            is_error: true,
          )

          output = tool_result.format

          assert_match(/ERROR/, output)
          assert_match(/error details/, output)
        end

        test "error_line strips the tool_use_error wrapper and upcases the tool name" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "<tool_use_error>File has not been read yet.</tool_use_error>",
            is_error: true,
          )

          output = tool_result.send(:error_line)

          assert_equal "BASH ERROR File has not been read yet.", output
        end

        test "error_line handles nil content gracefully" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "read", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: nil,
            is_error: true,
          )

          output = tool_result.send(:error_line)

          assert_equal "READ ERROR", output
        end

        test "format error path keeps the full content" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: "Error: command failed\n  at line 3\n  exit status 1",
            is_error: true,
          )

          output = tool_result.format

          assert_equal "UNKNOWN ERROR Error: command failed\n  at line 3\n  exit status 1", output
        end

        test "format routes errors through the error_line helper" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: "error details",
            is_error: true,
          )

          tool_result.expects(:error_line).returns("ERROR LINE")

          output = tool_result.format

          assert_equal "ERROR LINE", output
        end

        test "format includes description when present" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: { description: "Run command" } },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "output",
            is_error: false,
          )

          output = tool_result.format

          assert_match(/Run command/, output)
        end

        test "ok_line renders a bare OK line when given no parts" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: nil,
            is_error: false,
          )

          output = tool_result.send(:ok_line)

          assert_equal "BASH OK", output
        end

        test "ok_line appends a single part and upcases the tool name" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: nil,
            is_error: false,
          )

          output = tool_result.send(:ok_line, "3 files")

          assert_equal "BASH OK 3 files", output
        end

        test "ok_line joins multiple parts with a dot separator" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: nil,
            is_error: false,
          )

          output = tool_result.send(:ok_line, "3 lines", "preview text")

          assert_equal "BASH OK 3 lines · preview text", output
        end

        test "ok_line drops blank and nil parts before joining" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: nil,
            is_error: false,
          )

          output = tool_result.send(:ok_line, "3 lines", "", nil)

          assert_equal "BASH OK 3 lines", output
        end

        test "truncate returns strings within the limit unchanged" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: nil,
            is_error: false,
          )
          string_at_limit = "a" * Claude::ToolResult::TRUNCATE_LIMIT

          output = tool_result.send(:truncate, string_at_limit)

          assert_equal string_at_limit, output
        end

        test "truncate cuts longer strings to the limit with an ellipsis" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: nil,
            is_error: false,
          )
          limit = Claude::ToolResult::TRUNCATE_LIMIT

          output = tool_result.send(:truncate, "a" * (limit + 10))

          assert_equal "#{"a" * (limit - 3)}...", output
          assert_equal limit, output.length
        end

        test "truncate maps nil to an empty string" do
          tool_result = Claude::ToolResult.new(
            tool_use: nil,
            content: nil,
            is_error: false,
          )

          output = tool_result.send(:truncate, nil)

          assert_equal "", output
        end
      end
    end
  end
end
