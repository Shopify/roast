# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ToolUseTest < ActiveSupport::TestCase
            test "initialize sets name and input" do
              tool_use = ToolUse.new(name: :bash, input: { command: "ls" })

              assert_equal :bash, tool_use.name
              assert_equal({ command: "ls" }, tool_use.input)
            end

            test "format calls format_bash for bash tool" do
              tool_use = ToolUse.new(name: :bash, input: { command: "ls" })

              output = tool_use.format

              assert_match(/BASH/, output)
              assert_match(/command.*ls/, output)
            end

            test "format calls format_unknown for unknown tool" do
              tool_use = ToolUse.new(name: :unknown_tool, input: { arg: "value" })

              output = tool_use.format

              assert_match(/UNKNOWN \[unknown_tool\]/, output)
              assert_match(/arg.*value/, output)
            end

            test "format_unknown includes tool name and input" do
              tool_use = ToolUse.new(name: :custom, input: { key: "value" })

              output = tool_use.send(:format_unknown)

              assert_match(/UNKNOWN \[custom\]/, output)
              assert_match(/key.*value/, output)
            end
          end
        end
      end
    end
  end
end
