# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat(:lake) do
    model "gpt-4o-mini"
  end
end

execute do
  chat(:lake) { "What is the deepest lake?" }
end
