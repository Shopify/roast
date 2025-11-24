# typed: true
# frozen_string_literal: true

# This type annotation helps Sorbet type-check your workflow.
# It's optional if you don't want to use Sorbet.
#: self as Roast::DSL::Workflow

# This is the simplest possible Roast workflow.
# It sends a single prompt to a chat LLM and displays the response.

config {}

execute do
  chat do
    <<~PROMPT
      You are a friendly AI assistant helping someone learn Roast,
      a Ruby-based workflow system for AI tasks.

      Say hello and give them one encouraging tip about learning
      new tools. Keep it brief and friendly!
    PROMPT
  end
end
