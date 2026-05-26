# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
end

execute do
  cmd(:diff) do
    current = %x(git rev-parse --abbrev-ref HEAD).strip
    if current == "main"
      warn "on main, nothing to compare"
      skip!
    end
    merge_base = %x(git merge-base origin/main HEAD).strip
    diff = %x(git diff #{merge_base})
    if diff.strip.empty?
      warn "no diff vs origin/main — stage or commit your changes first"
      skip!
    end
    "git diff #{merge_base}"
  end

  agent(:analyzer) do
    <<~PROMPT
      Analyze how the following git diff affects existing documentation.

      DO NOT run git, bash, or any other commands. The diff is the ONLY input.
      DO NOT investigate the branch state, untracked files, or commit history.
      Work only from the diff below.

      --- DIFF START ---
      #{cmd!(:diff).text}
      --- DIFF END ---

      For each documentation file in this repo that the diff affects, report:
      1. The doc file path
      2. What in the diff makes it stale
      3. The specific edit needed to bring it back in sync
    PROMPT
  end

  chat do
    <<~PROMPT
      Based on the following analysis, summarize the impact of the changes in this branch on the project's documentation.
      Highlight any significant improvements or regressions, and provide recommendations for any additional documentation updates that may be necessary.
      Do not unecessarily suggest updates if they are not needed.

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
end
