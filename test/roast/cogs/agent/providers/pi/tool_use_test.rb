# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolUseTest < ActiveSupport::TestCase
            test "format_bash formats bash command" do
              tool_use = ToolUse.new(name: :bash, input: { command: "ls -la" })

              assert_equal "BASH ls -la", tool_use.format
            end

            test "format_read formats read path" do
              tool_use = ToolUse.new(name: :read, input: { path: "/tmp/file.rb" })

              assert_equal "READ /tmp/file.rb", tool_use.format
            end

            test "format_edit formats edit path" do
              tool_use = ToolUse.new(name: :edit, input: { path: "/tmp/file.rb" })

              assert_equal "EDIT /tmp/file.rb", tool_use.format
            end

            test "format_write formats write path" do
              tool_use = ToolUse.new(name: :write, input: { path: "/tmp/file.rb" })

              assert_equal "WRITE /tmp/file.rb", tool_use.format
            end

            test "format_grep formats grep command" do
              tool_use = ToolUse.new(name: :grep, input: { pattern: "TODO", path: "/tmp" })

              assert_equal "GREP TODO /tmp", tool_use.format
            end

            test "format_find formats find command" do
              tool_use = ToolUse.new(name: :find, input: { path: "/tmp", pattern: "*.rb" })

              assert_equal "FIND /tmp *.rb", tool_use.format
            end

            test "format_ls formats ls command" do
              tool_use = ToolUse.new(name: :ls, input: { path: "/tmp" })

              assert_equal "LS /tmp", tool_use.format
            end

            test "format_unknown for unrecognized tools" do
              tool_use = ToolUse.new(name: :custom_tool, input: { key: "value" })

              assert_match(/UNKNOWN \[custom_tool\]/, tool_use.format)
            end
          end
        end
      end
    end
  end
end
