# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    module Agent::Providers
      class Claude::ToolUseTest < ActiveSupport::TestCase
        test "initialize sets name and input" do
          tool_use = Claude::ToolUse.new(name: :bash, input: { command: "ls" })

          assert_equal :bash, tool_use.name
          assert_equal({ command: "ls" }, tool_use.input)
        end

        test "truncate returns the string unchanged at or below the limit" do
          tool_use = Claude::ToolUse.new(name: :bash, input: {})
          str = "a" * Claude::ToolUse::TRUNCATE_LIMIT

          output = tool_use.send(:truncate, str)

          assert_equal str, output
        end

        test "truncate appends ellipsis and stays at the limit for strings over it" do
          tool_use = Claude::ToolUse.new(name: :bash, input: {})
          str = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 1)

          output = tool_use.send(:truncate, str)

          assert_equal "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}...", output
        end

        test "truncate handles nil without crashing" do
          tool_use = Claude::ToolUse.new(name: :bash, input: {})

          output = tool_use.send(:truncate, nil)

          assert_equal "", output
        end

        test "truncate returns an empty string for an empty input" do
          tool_use = Claude::ToolUse.new(name: :bash, input: {})
          assert_equal "", tool_use.send(:truncate, "")
        end

        # format_bash

        test "format_bash renders the command only when no description given" do
          tool_use = Claude::ToolUse.new(name: :bash, input: { command: "ls -la" })

          output = tool_use.format

          assert_equal "BASH ls -la", output
        end

        test "format_bash appends description in parentheses" do
          tool_use = Claude::ToolUse.new(name: :bash, input: { command: "ls -la", description: "List directory contents" })

          output = tool_use.format

          assert_equal "BASH ls -la (List directory contents)", output
        end

        test "format_bash truncates command but not description" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          tool_use = Claude::ToolUse.new(name: :bash, input: { command: long, description: long })

          output = tool_use.format

          assert_equal "BASH #{truncated} (#{long})", output
        end

        test "format_bash has no trailing space when the command is absent" do
          tool_use = Claude::ToolUse.new(name: :bash, input: {})

          output = tool_use.format

          assert_equal "BASH", output
        end

        # format_read

        test "format_read shows a closed range when offset and limit are set" do
          tool_use = Claude::ToolUse.new(name: :read, input: { file_path: "/a.rb", offset: 30, limit: 51 })

          output = tool_use.format

          assert_equal "READ /a.rb (lines 30–80)", output
        end

        test "format_read defaults offset to 1 when only limit is given" do
          tool_use = Claude::ToolUse.new(name: :read, input: { file_path: "/a.rb", limit: 50 })

          output = tool_use.format

          assert_equal "READ /a.rb (lines 1–50)", output
        end

        test "format_read shows an open-ended range from offset when limit is absent" do
          tool_use = Claude::ToolUse.new(name: :read, input: { file_path: "/a.rb", offset: 30 })

          output = tool_use.format

          assert_equal "READ /a.rb (from line 30)", output
        end

        test "format_read renders a bare line with only a file path" do
          tool_use = Claude::ToolUse.new(name: :read, input: { file_path: "/a.rb" })

          output = tool_use.format

          assert_equal "READ /a.rb", output
        end

        test "format_read has no trailing space when the file path is absent" do
          tool_use = Claude::ToolUse.new(name: :read, input: {})

          output = tool_use.format

          assert_equal "READ", output
        end

        test "format calls format_unknown for unknown tool" do
          tool_use = Claude::ToolUse.new(name: :unknown_tool, input: { arg: "value" })

          output = tool_use.format

          assert_match(/UNKNOWN \[unknown_tool\]/, output)
          assert_match(/arg.*value/, output)
        end

        test "format_unknown includes tool name and input" do
          tool_use = Claude::ToolUse.new(name: :custom, input: { key: "value" })

          output = tool_use.send(:format_unknown)

          assert_match(/UNKNOWN \[custom\]/, output)
          assert_match(/key.*value/, output)
        end
      end
    end
  end
end
