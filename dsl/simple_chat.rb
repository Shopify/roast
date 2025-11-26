# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat { assume_model_exists! }
  chat(:lake) { model("gpt-4o") }
  chat(:next) { model("gpt-4o-mini") }
end

execute do
  # Ask a question
  chat(:lake) { "What is the deepest lake?" }

  # Continue the conversation (with a different model!)
  chat(:next) do |my|
    my.prompt = "What answer did you just give, and why?"
    my.session = chat!(:lake).session
  end

  # Ask a question with a template prompt. You can pass variables to it as you would an ERB template
  chat { template("dsl/prompts/simple_prompt.md.erb", { lake_answer: chat!(:lake).response }) }

  # Shorthand to look up a template prompt
  # chat { template("simple_prompt", { lake_answer: chat!(:lake).response }) }
end
