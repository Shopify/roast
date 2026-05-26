# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :claude
    model "claude-opus-4-7"
    quiet!
  end
  chat do
    provider :openai
    model "gpt-5"
    quiet!
  end
end

execute do
  cmd(:diff) do
    merge_base = %x(git merge-base origin/main HEAD).strip
    diff = %x(git diff --cached #{merge_base})
    if diff.strip.empty?
      warn "no staged or committed changes vs origin/main"
      skip!
    end
    "git diff --cached #{merge_base}"
  end

  agent(:analyzer) do
    <<~PROMPT
      You are checking whether a git diff makes any existing documentation stale.

      Rules:
      - Use ONLY the diff below. Do not run any commands.
      - Be thorough about finding real issues — do not be conservative.
      - But do NOT speculate about docs you cannot see in the diff.
      - No markdown headers, no preamble, no caveats, no "limitations" sections.

      Output format — pick exactly one:

      If nothing in the diff affects existing docs, output a single line:
        No documentation impact.

      Otherwise, output one block per affected doc, separated by blank lines:
        <doc/path.md>
        Stale because: <one sentence>
        Fix: <one sentence>

      --- DIFF START ---
      #{cmd!(:diff).text}
      --- DIFF END ---
    PROMPT
  end

  chat(:report) do
    <<~PROMPT
      Based on the following analysis, summarize the impact of the changes in this branch on the project's documentation.
      Highlight any significant improvements or regressions, and provide recommendations for any additional documentation updates that may be necessary.
      Do not unecessarily suggest updates if they are not needed.
      Do not be verbose. Be super concise.

      Analysis:
      #{agent!(:analyzer).response}
    PROMPT
  end

  agent(:fixer) do
    skip! unless arg?(:fix)
    <<~PROMPT
      Apply the documentation fixes suggested in the analysis below. Edit the
      affected files in place. Do not modify any code files; docs only.

      #{agent!(:analyzer).response}
    PROMPT
  end

  ruby(:output) do
    files = cmd!(:diff).text.scan(%r{^diff --git a/\S+ b/(\S+)}).flatten

    puts "Files considered (#{files.size}):"
    files.each { |f| puts "  #{f}" }
    puts agent!(:analyzer).response
    puts(agent?(:fixer) ? "Fixes applied." : "(Run with -- fix to apply suggested edits.)")
  end
end
