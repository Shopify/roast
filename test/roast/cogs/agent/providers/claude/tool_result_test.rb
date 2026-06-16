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

        test "format_unknown includes the description for an unknown tool" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "custom", input: { description: "Run command" } },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "output",
            is_error: false,
          )

          output = tool_result.format

          assert_match(/Run command/, output)
        end

        test "format_bash reports the line count and previews the first line" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "file1.txt\nfile2.txt\nfile3.txt",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "BASH OK 3 lines · file1.txt", output
        end

        test "format_bash uses the singular 'line' for a single line of output" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "the only line",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "BASH OK 1 line · the only line", output
        end

        test "format_bash truncates a long first-line preview" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "x" * 60,
            is_error: false,
          )

          output = tool_result.format

          assert_equal "BASH OK 1 line · #{"x" * (Claude::ToolResult::TRUNCATE_LIMIT - 3)}...", output
        end

        test "format_bash omits the preview when the command produced no output" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "bash", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "BASH OK 0 lines", output
        end

        test "format_read uses the plural 'lines' for multiple lines of content" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "read", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "line one\nline two\nline three",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "READ OK 3 lines", output
        end

        test "format_read uses the singular 'line' for a single line of content" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "read", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "the only line",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "READ OK 1 line", output
        end

        test "format_read does not count a trailing newline as an extra line" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "read", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "line one\nline two\n",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "READ OK 2 lines", output
        end

        test "format_read reports zero lines for empty content" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "read", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "READ OK 0 lines", output
        end

        test "format_glob reports the number of matched files" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "/a/one.rb\n/a/two.rb\n/a/three.rb",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 3 files found", output
        end

        test "format_glob uses the singular 'file' for a single match" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "/a/only.rb",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 1 file found", output
        end

        test "format_glob ignores blank lines when counting files" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "/a/one.rb\n\n/a/two.rb\n",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 2 files found", output
        end

        test "format_glob appends a non-path line as a NOTE when files were found" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "/a/one.rb\n/a/two.rb\nResults are truncated",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 2 files found · NOTE Results are truncated", output
        end

        test "format_glob drops the NOTE when there are no matches" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "No files found",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 0 files found", output
        end

        test "format_glob truncates a long NOTE" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "glob", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "/a/only.rb\n#{"x" * 60}",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GLOB OK 1 file found · NOTE #{"x" * (Claude::ToolResult::TRUNCATE_LIMIT - 3)}...", output
        end

        test "format_grep reports the number of matches" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "lib/a.rb:1:foo\nlib/b.rb:2:bar\nlib/c.rb:3:baz",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 3 matches", output
        end

        test "format_grep counts a line-number-prefixed match without a path" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "42:def hello",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 1 match", output
        end

        test "format_grep ignores blank lines when counting matches" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "lib/a.rb:1:foo\n\nlib/b.rb:2:bar\n",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 2 matches", output
        end

        test "format_grep appends a non-match line as a NOTE when matches were found" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "lib/a.rb:1:foo\nlib/b.rb:2:bar\nResults are truncated",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 2 matches · NOTE Results are truncated", output
        end

        test "format_grep drops the NOTE when there are no matches" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "No matches found",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 0 matches", output
        end

        test "format_grep truncates a long NOTE" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "lib/a.rb:1:foo\n#{"x" * 60}",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 1 match · NOTE #{"x" * (Claude::ToolResult::TRUNCATE_LIMIT - 3)}...", output
        end

        test "format_grep does not misclassify a status message containing a slash as a match" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "lib/a.rb:1:foo\nFound 0/100 files",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 1 match · NOTE Found 0/100 files", output
        end

        test "format_grep counts bare relative paths as matches" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "components/a.rb\ncomponents/b.rb",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 2 matches", output
        end

        test "format_grep counts a root-level file match whose path has no slash" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "grep", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "Gemfile:395:gem \"verdict\"",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "GREP OK 1 match", output
        end

        test "format_write reports the written file path" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "write", input: { file_path: "lib/roast/version.rb" } },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "File created successfully",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "WRITE OK lib/roast/version.rb", output
        end

        test "format_write omits the path when the input has none" do
          tool_use_message = Claude::Messages::ToolUseMessage.new(
            type: :tool_use,
            hash: { name: "write", input: {} },
          )
          tool_result = Claude::ToolResult.new(
            tool_use: tool_use_message,
            content: "File created successfully",
            is_error: false,
          )

          output = tool_result.format

          assert_equal "WRITE OK", output
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
