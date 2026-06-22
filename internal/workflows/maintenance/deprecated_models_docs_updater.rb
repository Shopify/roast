# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# Looks at the Anthropic (https://platform.claude.com/docs/en/about-claude/model-deprecations) and
# OpenAI (https://developers.openai.com/api/docs/deprecations) model-deprecation pages and updates all
# docs, doc comments and code references to deprecated/retired models to reflect those changes. This is
# meant to be run periodically to keep all the references to models up to date.

config do
  agent do
    provider :claude
    model "claude-opus-4-8"
    quiet!
  end
end

execute do
  agent(:model_verifier) do
    <<~PROMPT
      Check both of these pages for deprecated/retired models and their suggested replacements:
      - Anthropic (Claude): https://platform.claude.com/docs/en/about-claude/model-deprecations
      - OpenAI: https://developers.openai.com/api/docs/deprecations

      Include every deprecated or retired model that has a recommended replacement, from both pages.
      Only include models — ignore deprecated API endpoints, tools, or other non-model features.

      Output ONLY a JSON object of exactly this shape, with no surrounding prose:
      {"outdated": [{"model": "<outdated_model>", "replacement": "<replacement_model>"}]}

      If there are none, output {"outdated": []}.
    PROMPT
  end

  agent(:model_finder) do
    <<~PROMPT
      You are a code search engine. Search through the codebase and documentation for any references to
      the outdated models below, including test files, and list every place where they are mentioned.

      The input is a JSON object of the form:
      {"outdated": [{"model": "<outdated_model>", "replacement": "<replacement_model>"}]}

      INPUT:
      #{agent!(:model_verifier).response}

      Output ONLY a JSON object of exactly this shape, with no surrounding prose, carrying the
      replacement through for each model you find a reference to:
      {"references": [{"model": "<outdated_model>", "replacement": "<replacement_model>", "locations": ["<file_path>:<line_number>"]}]}

      If you find no references, output {"references": []}.
    PROMPT
  end

  agent(:updater) do |my|
    finder = agent!(:model_finder)
    skip! if finder.json!.fetch(:references, []).empty?
    my.session = finder.session
    <<~PROMPT
      For each reference you found of an outdated model, update the reference to use the suggested replacement model instead. Make sure to update all types of references, including documentation, doc comments and code references. Output the list of updated references in the following format:
      <outdated_model_1> -> <replacement_model_1>:
      - <file_path>:<line_number>
      <outdated_model_2> -> <replacement_model_2>:
      - <file_path>:<line_number>
      ...
    PROMPT
  end

  ruby(:output) do
    if agent?(:updater)
      puts "[OUTDATED MODELS & REPLACEMENTS]\n #{agent!(:model_verifier).response}"
      puts "[REFERENCES IN CODEBASE]\n #{agent!(:model_finder).response}"
      puts "[UPDATED REFERENCES]\n #{agent!(:updater).response}"
    else
      puts "No references to outdated models found — nothing to update."
    end
  end
end
