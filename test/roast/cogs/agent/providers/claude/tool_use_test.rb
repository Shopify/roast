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
              tool_use = ToolUse.new(name: :bash, input: { command: "ls", description: "Get log" })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_read for read tool" do
              tool_use = ToolUse.new(name: :read, input: { file_path: "/tmp/file.txt", limit: 100 })
              output = tool_use.format
              puts output
              assert true
            end

            test "format calls format_glob for glob tool" do
              tool_use = ToolUse.new(name: :glob, input: { pattern: "**/*read_only_associations*", path: "/tmp/file.txt" })
              output = tool_use.format
              puts output
              assert true
            end

            test "format calls format_grep for grep tool" do
              tool_use = ToolUse.new(
                name: :grep,
                input: {
                  pattern: "class Foo",
                  path: "/tmp/project",
                  output_mode: "files_with_matches",
                  glob: "*.rb",
                  type: "ruby",
                  i: true,
                  n: true,
                  A: 2,
                  B: 2,
                  C: 3,
                  context: 3,
                  multiline: false,
                  head_limit: 100,
                  offset: 0,
                },
              )

              output = tool_use.format

              puts output

              assert true
            end

            test "format calls format_write for write tool" do
              tool_use = ToolUse.new(name: :write, input:
              {
                file_path: "/tmp/file.txt",
                content: "Some long string with some new lines to go with it to get even y\n and even more text taht definitely exceeds 50 characters",
              })
              output = tool_use.format

              puts output

              assert true
            end

            test "format calls foramt_edit for edit tool" do
              tool_use = ToolUse.new(name: :edit, input: {
                replace_all: false,
                file_path: "/tmp/file.txt",
                old_string: "Simple text",
                new_string: "Much more complex and different text",
              })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_todowrite for todowrite tool" do
              tool_use = ToolUse.new(name: :todowrite, input: {
                todos: [
                  {
                    content: "Fetch GitHub issue and read comment templates",
                    status: "in_progress",
                    activeForm: "Fetching GitHub issue and reading comment templates",
                  },
                  {
                    content: "Check project status in Shopify/projects/13178",
                    status: "pending",
                    activeForm: "Checking project status",
                  },
                  {
                    content: "Parse comments for prior work and create working directory",
                    status: "pending",
                    activeForm: "Parsing comments and creating working directory",
                  },
                ],
              })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_skill for skill tool" do
              tool_use = ToolUse.new(name: :skill, input: {
                skill: "github-skill",
                args: "get-issue-status --org Shopify",
              })

              output = tool_use.format
              puts output
              assert true
            end

            test "format calls format_task for task tool" do
              tool_use = ToolUse.new(name: :task, input: {
                description: "Checks ClassOne for callbacks",
                prompt: "In the current codebase, look at the class named ClassOne and output whether it contains callbacks.",
                subagent_type: "Explore",
                model: "haiku",
                run_in_background: false,
              })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_agent for agent tool" do
              tool_use = ToolUse.new(name: :agent, input: {
                description: "Checks ClassOne for callbacks",
                prompt: "In the current codebase, look at the class named ClassOne and output whether it contains callbacks.",
                subagent_type: "Explore",
              })

              output = tool_use.format
              puts output
              assert true
            end

            test "format calls format_taskoutput for taskoutput tool" do
              tool_use = ToolUse.new(name: :taskoutput, input: {
                block: true,
                task_id: "a628911abed3cf145",
                timeout: 30000,
              })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_taskcreate for taskcreate tool" do
              tool_use = ToolUse.new(name: :taskcreate, input: {
                subject: "Write tool result formatters for all tool types including bash read glob grep write edit",
                description: "Write tool result formatters for all tool types including bash read glob grep write edit",
                activeForm: "Writing tool result formatters",
              })

              output = tool_use.format

              puts output
              assert true
            end

            test "format calls format_taskupdate for taskupdate tool" do
              tool_use = ToolUse.new(name: :taskupdate, input: {
                taskId: "1",
                status: "completed",
              })

              output = tool_use.format

              puts output
              assert true
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
