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
      Please do ALL of the following steps in order, using the exact tools specified. Do not use Bash as a substitute for Glob, Grep, Read, Write, or Edit.

      1. Use Glob to find all .rb files under lib/roast/cogs/agent/providers/claude/messages/

      2. Use Grep to search for the pattern "def format" in lib/roast/cogs/agent/providers/claude/ with glob filter "*.rb" and case-insensitive flag enabled.

      3. Use Read to read lib/roast/cogs/agent/providers/claude/tool_use.rb, lines 30 to 80 only

      4. Use Bash to run: echo "this is a very long bash command output that tests whether our truncation logic handles long command strings gracefully without breaking the formatter" with description "Stress testing the bash formatter with an intentionally long command string to verify truncation at 50 characters"

      5. Use Write to create tmp/formatter_stress_test.txt with exactly this content (10 long lines):
      line 001: The quick brown fox jumps over the lazy dog while the formatter watches carefully to see if long lines get truncated properly
      line 002: Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua
      line 003: Pack my box with five dozen liquor jugs as the formatter stress test begins its long and arduous journey through truncation
      line 004: How vexingly quick daft zebras jump when the tool use formatter is watching and waiting to see what happens with long content
      line 005: The five boxing wizards jump quickly past the formatter which is now handling extremely long first-line content in write calls
      line 006: Sphinx of black quartz judge my vow and also test whether the formatter correctly truncates this extremely verbose line content
      line 007: Waltz nymphs for quick jigs vex bud as the formatter continues to handle more and more lines with increasingly long content
      line 008: Bright vixens jump dozy fowl quack as this formatter test reaches line eight with content that keeps going and going endlessly
      line 009: Glib jocks quiz nymph to vex dwarf and the formatter must handle this penultimate line which is also quite long in character count
      line 010: Jackdaws love my big sphinx of quartz and this is the final line of the stress test file which the formatter must handle gracefully

      6. Use Edit to replace lines 4 through 9 (a 6-line block) with uppercased first words:
      old_string should be exactly:
      line 004: How vexingly quick daft zebras jump when the tool use formatter is watching and waiting to see what happens with long content
      line 005: The five boxing wizards jump quickly past the formatter which is now handling extremely long first-line content in write calls
      line 006: Sphinx of black quartz judge my vow and also test whether the formatter correctly truncates this extremely verbose line content
      line 007: Waltz nymphs for quick jigs vex bud as the formatter continues to handle more and more lines with increasingly long content
      line 008: Bright vixens jump dozy fowl quack as this formatter test reaches line eight with content that keeps going and going endlessly
      line 009: Glib jocks quiz nymph to vex dwarf and the formatter must handle this penultimate line which is also quite long in character count

      new_string should be:
      line 004: HOW vexingly quick daft zebras jump when the tool use formatter is watching and waiting to see what happens with long content
      line 005: THE five boxing wizards jump quickly past the formatter which is now handling extremely long first-line content in write calls
      line 006: SPHINX of black quartz judge my vow and also test whether the formatter correctly truncates this extremely verbose line content
      line 007: WALTZ nymphs for quick jigs vex bud as the formatter continues to handle more and more lines with increasingly long content
      line 008: BRIGHT vixens jump dozy fowl quack as this formatter test reaches line eight with content that keeps going and going endlessly
      line 009: GLIB jocks quiz nymph to vex dwarf and the formatter must handle this penultimate line which is also quite long in character count

      7. Use TodoWrite to set these five todos:
         - "Run formatter stress test" (status: completed, activeForm: "Running formatter stress test")
         - "Review multiline edit output in tmp/formatter_stress_test.txt to verify all 6 lines were uppercased correctly" (status: in_progress, activeForm: "Reviewing multiline edit output in tmp/formatter_stress_test.txt")
         - "Write tool result formatters for all tool types including bash read glob grep write edit todowrite skill task agent taskoutput" (status: pending, activeForm: "Writing tool result formatters")
         - "Update snapshot file for team review and share with the broader engineering team for feedback on formatting decisions" (status: pending, activeForm: "Updating snapshot file")
         - "Open PR for tool use formatter implementation and request reviews from team members who were consulted during design" (status: pending, activeForm: "Opening PR for tool use formatter")

      Confirm each step as you go.
    PROMPT
  end
end
