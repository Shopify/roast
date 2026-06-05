# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# Gets the committed diff of the current branch vs origin/main, then analyzes it for potential
# documentation impacts, and optionally applies fixes. This is meant to be run as a pre-merge check, to
# catch any potential documentation issues before they get merged into main.
#
# Accepts a `--fix` flag to apply any suggested fixes in place. Otherwise, it just reports the analysis
# and recommended fixes without applying them.

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
    fail!("could not determine merge-base with origin/main — run `git fetch origin main` first") if merge_base.empty?
    "git diff #{merge_base} HEAD"
  end

  agent(:analyzer) do
    skip! if cmd!(:diff).text.strip.empty?
    fail!("diff too large (#{cmd!(:diff).text.bytesize} bytes) to analyze — narrow the branch or exclude generated files") if cmd!(:diff).text.bytesize > 500_000
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
    skip! if cmd!(:diff).text.strip.empty?
    <<~PROMPT
      Based on the following analysis, summarize the impact of the changes in this branch on the project's documentation.
      Highlight any significant improvements or regressions, and provide recommendations for any additional documentation updates that may be necessary.
      Do not suggest updates that are not needed.
      Do not be verbose. Be super concise.

      Analysis:
      #{agent!(:analyzer).response}
    PROMPT
  end

  agent(:fixer) do
    skip! unless arg?(:fix)
    skip! if cmd!(:diff).text.strip.empty?
    skip! if agent!(:analyzer).response.strip == "No documentation impact."
    <<~PROMPT
      Apply the documentation fixes suggested in the analysis below. Edit the
      affected files in place. Do not modify any code files; docs only.

      #{agent!(:analyzer).response}
    PROMPT
  end

  ruby(:output) do
    if cmd!(:diff).text.strip.empty?
      puts "No changes vs origin/main — nothing to analyze."
    else
      files = cmd!(:diff).out.scan(%r{^diff --git a/.+ b/(.+)$}).flatten
      puts "Files considered (#{files.size}):"
      files.each { |f| puts "  #{f}" }
      puts "ANALYSIS:\n#{chat!(:report).response}"
      puts(agent?(:fixer) ? "Fixes applied." : "(Next time, run with `-- fix` to auto-apply suggested edits)")
    end
  end
end
