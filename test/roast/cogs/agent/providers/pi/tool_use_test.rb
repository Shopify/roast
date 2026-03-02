# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolUseTest < ActiveSupport::TestCase
            test "initialize sets name and arguments" do
              tool_use = ToolUse.new(name: "bash", arguments: { command: "ls" })

              assert_equal "bash", tool_use.name
              assert_equal({ command: "ls" }, tool_use.arguments)
            end

            test "format_bash shows command" do
              tool_use = ToolUse.new(name: "bash", arguments: { command: "ls -la" })

              assert_equal "BASH: ls -la", tool_use.format
            end

            test "format_bash uses cmd key as fallback" do
              tool_use = ToolUse.new(name: "bash", arguments: { cmd: "echo hello" })

              assert_equal "BASH: echo hello", tool_use.format
            end

            test "format_read shows path" do
              tool_use = ToolUse.new(name: "read", arguments: { path: "/tmp/test.txt" })

              assert_equal "READ: /tmp/test.txt", tool_use.format
            end

            test "format_write shows path" do
              tool_use = ToolUse.new(name: "write", arguments: { path: "/tmp/output.txt" })

              assert_equal "WRITE: /tmp/output.txt", tool_use.format
            end

            test "format_edit shows path" do
              tool_use = ToolUse.new(name: "edit", arguments: { path: "/tmp/file.rb" })

              assert_equal "EDIT: /tmp/file.rb", tool_use.format
            end

            test "format_grep shows pattern and path" do
              tool_use = ToolUse.new(name: "grep", arguments: { pattern: "TODO", path: "src/" })

              assert_equal "GREP: TODO in src/", tool_use.format
            end

            test "format_grep shows pattern without path" do
              tool_use = ToolUse.new(name: "grep", arguments: { pattern: "TODO" })

              assert_equal "GREP: TODO", tool_use.format
            end

            test "format_grep uses query key as fallback" do
              tool_use = ToolUse.new(name: "grep", arguments: { query: "FIXME" })

              assert_equal "GREP: FIXME", tool_use.format
            end

            test "format_find shows pattern and path" do
              tool_use = ToolUse.new(name: "find", arguments: { pattern: "*.rb", path: "lib/" })

              assert_equal "FIND: *.rb in lib/", tool_use.format
            end

            test "format_find uses dir and name keys as fallback" do
              tool_use = ToolUse.new(name: "find", arguments: { name: "*.txt", dir: "/tmp" })

              assert_equal "FIND: *.txt in /tmp", tool_use.format
            end

            test "format_ls shows path" do
              tool_use = ToolUse.new(name: "ls", arguments: { path: "/tmp" })

              assert_equal "LS: /tmp", tool_use.format
            end

            test "format_unknown shows tool name and arguments" do
              tool_use = ToolUse.new(name: "custom_tool", arguments: { key: "value" })

              output = tool_use.format

              assert_match(/TOOL \[custom_tool\]/, output)
              assert_match(/key.*value/, output)
            end

            test "format dispatches to known tools" do
              %w[bash read write edit grep find ls].each do |tool_name|
                tool_use = ToolUse.new(name: tool_name, arguments: { path: "/test" })

                # Should not include "TOOL [" prefix (that's the unknown format)
                refute_match(/^TOOL \[/, tool_use.format)
              end
            end
          end
        end
      end
    end
  end
end
