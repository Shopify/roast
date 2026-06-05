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

        # format_glob

        test "format_glob renders the pattern only when no path given" do
          tool_use = Claude::ToolUse.new(name: :glob, input: { pattern: "**/*.rb" })

          output = tool_use.format

          assert_equal "GLOB **/*.rb", output
        end

        test "format_glob appends the search path in parentheses" do
          tool_use = Claude::ToolUse.new(name: :glob, input: { pattern: "**/*.rb", path: "lib/roast" })

          output = tool_use.format

          assert_equal "GLOB **/*.rb (in lib/roast)", output
        end

        # format_grep

        test "format_grep renders the quoted pattern alone with no path or modifiers" do
          tool_use = Claude::ToolUse.new(name: :grep, input: { pattern: "TODO" })

          output = tool_use.format

          assert_equal "GREP \"TODO\"", output
        end

        test "format_grep appends the search path after the pattern" do
          tool_use = Claude::ToolUse.new(name: :grep, input: { pattern: "TODO", path: "lib/roast" })

          output = tool_use.format

          assert_equal "GREP \"TODO\" lib/roast", output
        end

        test "format_grep wraps a modifier with the path present" do
          tool_use = Claude::ToolUse.new(name: :grep, input: { pattern: "TODO", path: "lib", glob: "*.rb" })

          output = tool_use.format

          assert_equal "GREP \"TODO\" lib (glob=*.rb)", output
        end

        test "format_grep joins glob, type, and case-insensitive modifiers in order" do
          tool_use = Claude::ToolUse.new(name: :grep, input: { pattern: "TODO", glob: "*.rb", type: "ruby", "-i": true })

          output = tool_use.format

          assert_equal "GREP \"TODO\" (glob=*.rb · type=ruby · -i)", output
        end

        test "format_grep truncates the pattern but not the path" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          tool_use = Claude::ToolUse.new(name: :grep, input: { pattern: long, path: long })

          output = tool_use.format

          assert_equal "GREP \"#{truncated}\" #{long}", output
        end

        # format_write

        test "format_write shows the preview and a singular count for one line" do
          tool_use = Claude::ToolUse.new(name: :write, input: { file_path: "/a.rb", content: "hello" })

          output = tool_use.format

          assert_equal "WRITE /a.rb \"hello\" (+1 line)", output
        end

        test "format_write strips the preview and counts every line" do
          tool_use = Claude::ToolUse.new(name: :write, input: { file_path: "/a.rb", content: "  def foo\n  bar\n  baz" })

          output = tool_use.format

          assert_equal "WRITE /a.rb \"def foo\" (+3 lines)", output
        end

        test "format_write truncates the preview" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          tool_use = Claude::ToolUse.new(name: :write, input: { file_path: "/a.rb", content: long })

          output = tool_use.format

          assert_equal "WRITE /a.rb \"#{truncated}\" (+1 line)", output
        end

        # format_edit

        test "format_edit shows the line counts of a single-line replacement" do
          tool_use = Claude::ToolUse.new(name: :edit, input: { file_path: "/a.rb", old_string: "foo", new_string: "bar" })

          output = tool_use.format

          assert_equal "EDIT /a.rb (-1 +1 lines)", output
        end

        test "format_edit counts the lines spanned by each string" do
          tool_use = Claude::ToolUse.new(name: :edit, input: { file_path: "/a.rb", old_string: "a\nb", new_string: "x" })

          output = tool_use.format

          assert_equal "EDIT /a.rb (-2 +1 lines)", output
        end

        test "format_edit appends replace all when the flag is set" do
          input = { file_path: "/a.rb", old_string: "foo", new_string: "bar", replace_all: true }
          tool_use = Claude::ToolUse.new(name: :edit, input: input)

          output = tool_use.format

          assert_equal "EDIT /a.rb (-1 +1 lines · replace all)", output
        end

        test "format_edit shows zero counts when the strings are absent" do
          tool_use = Claude::ToolUse.new(name: :edit, input: { file_path: "/a.rb" })

          output = tool_use.format

          assert_equal "EDIT /a.rb (-0 +0 lines)", output
        end

        # format_todowrite

        test "format_todowrite shows a zero count and no breakdown for an empty list" do
          tool_use = Claude::ToolUse.new(name: :todowrite, input: {})

          output = tool_use.format

          assert_equal "TODOWRITE 0 todos", output
        end

        test "format_todowrite uses the singular label for a single todo" do
          tool_use = Claude::ToolUse.new(name: :todowrite, input: { todos: [{ status: "pending" }] })

          output = tool_use.format

          assert_equal "TODOWRITE 1 todo (1 pending)", output
        end

        test "format_todowrite tallies each status with its count" do
          todos = [{ status: "completed" }, { status: "pending" }, { status: "completed" }]
          tool_use = Claude::ToolUse.new(name: :todowrite, input: { todos: todos })

          output = tool_use.format

          assert_equal "TODOWRITE 3 todos (2 completed · 1 pending)", output
        end

        test "format_todowrite orders the breakdown by where each status first appears" do
          todos = [{ status: "pending" }, { status: "completed" }, { status: "completed" }]
          tool_use = Claude::ToolUse.new(name: :todowrite, input: { todos: todos })

          output = tool_use.format

          assert_equal "TODOWRITE 3 todos (1 pending · 2 completed)", output
        end

        # format_skill

        test "format_skill renders the skill name alone when no args given" do
          tool_use = Claude::ToolUse.new(name: :skill, input: { skill: "pr-description" })

          output = tool_use.format

          assert_equal "SKILL pr-description", output
        end

        test "format_skill appends args in parentheses" do
          tool_use = Claude::ToolUse.new(name: :skill, input: { skill: "pr-description", args: "draft for auth" })

          output = tool_use.format

          assert_equal "SKILL pr-description (draft for auth)", output
        end

        test "format_skill truncates args but not the skill name" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          tool_use = Claude::ToolUse.new(name: :skill, input: { skill: long, args: long })

          output = tool_use.format

          assert_equal "SKILL #{long} (#{truncated})", output
        end

        # format_task

        test "format_task renders the description alone with no optional fields" do
          tool_use = Claude::ToolUse.new(name: :task, input: { description: "Find all callers" })

          output = tool_use.format

          assert_equal "TASK Find all callers", output
        end

        test "format_task joins subagent type, background, and model in order" do
          input = { description: "Audit", run_in_background: true, subagent_type: "Explore", model: "opus" }
          tool_use = Claude::ToolUse.new(name: :task, input: input)

          output = tool_use.format

          assert_equal "TASK Audit (Explore · background · opus)", output
        end

        test "format_task omits background when run_in_background is false" do
          tool_use = Claude::ToolUse.new(name: :task, input: { description: "Audit", run_in_background: false })

          output = tool_use.format

          assert_equal "TASK Audit", output
        end

        test "format_task truncates the description but not the subagent type or model" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          input = { description: long, subagent_type: long, model: long }
          tool_use = Claude::ToolUse.new(name: :task, input: input)

          output = tool_use.format

          assert_equal "TASK #{truncated} (#{long} · #{long})", output
        end

        # format_agent

        test "format_agent renders the description alone with no optional fields" do
          tool_use = Claude::ToolUse.new(name: :agent, input: { description: "Find all callers" })

          output = tool_use.format

          assert_equal "AGENT Find all callers", output
        end

        test "format_agent renders the description with all optional fields" do
          input = { description: "Audit", run_in_background: true, subagent_type: "Explore" }
          tool_use = Claude::ToolUse.new(name: :agent, input: input)

          output = tool_use.format

          assert_equal "AGENT Audit (Explore · background)", output
        end

        test "format_agent truncates the description but not the subagent type" do
          long = "a" * (Claude::ToolUse::TRUNCATE_LIMIT + 10)
          truncated = "#{"a" * (Claude::ToolUse::TRUNCATE_LIMIT - 3)}..."
          input = { description: long, subagent_type: long }
          tool_use = Claude::ToolUse.new(name: :agent, input: input)

          output = tool_use.format

          assert_equal "AGENT #{truncated} (#{long})", output
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
