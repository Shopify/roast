# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat(:lake) do
    model("gpt-4o-mini")
    assume_model_exists(true)
  end
end

execute do
  chat(:lake) { "What is the deepest lake?" }
end
