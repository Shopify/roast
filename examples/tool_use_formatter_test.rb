# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :claude
    show_progress!
    dump_raw_agent_messages_to "tmp/tool-formatter-test.log"
  end
end

execute do
  agent(:trigger_all_tools) do
    <<~PROMPT
      Please do the following steps in order, using tools for each one:

      1. Use Glob to find all .rb files under lib/roast/cogs/agent/providers/claude/
      2. Use Grep to search for "def format" in lib/roast/cogs/agent/providers/claude/
      3. Use Read to read lib/roast/cogs/agent/providers/claude/tool_use.rb
      4. Use Bash to run: echo "hello from bash"
      5. Use Write to create tmp/formatter_test.txt with the content "line one\nline two\nline three"
      6. Use Edit to change "line two" to "line TWO" in tmp/formatter_test.txt
      7. Use TodoWrite to set one in_progress todo: "Review formatter output"

      Do all steps sequentially and confirm each one is done.
    PROMPT
  end
end
