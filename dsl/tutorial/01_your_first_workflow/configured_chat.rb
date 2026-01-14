# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates how to configure chat cogs.
# Configuration is set in a 'config' block before the 'execute' block.

config do
  # Configure all chat cogs in this workflow
  chat do
    model "gpt-4o-mini"      # Use OpenAI's fast, cost-effective model
    provider :openai         # Use OpenAI (alternative: :anthropic)
    show_prompt!             # Display the prompt before sending it
    show_response!           # Display the response (this is the default)
    show_stats!              # Display token usage statistics (default)
  end
end

execute do
  chat do
    <<~PROMPT
      You are a knowledgeable software development assistant.

      Explain what a "workflow" is in the context of software automation,
      using simple language that a beginner could understand.

      Provide a brief example of when you might use a workflow.

      Keep your response to 3-4 sentences.
    PROMPT
  end
end
