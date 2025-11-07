# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat(:lake) do
    model("gpt-4o")
    assume_model_exists(true)
  end
end

execute do
  # Ask a question
  chat(:lake) { "What is the deepest lake?" }

  # Ask a question with a template prompt. You can pass variables to it as you would an ERB template
  chat { template("dsl/prompts/simple_prompt.md.erb", { lake_answer: chat!(:lake).response }) }

  # Shorthand to look up a template prompt
  # chat { template("simple_prompt", { lake_answer: chat!(:lake).response }) }
end
