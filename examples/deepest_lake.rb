# typed: false
# frozen_string_literal: true

#: self as Roast::Workflow

# Simple chat workflow example that asks about the deepest lake

config do
  chat(:test) { model("gpt-4o") }
end

execute do
  chat(:test) { "What is the deepest lake?" }
end
