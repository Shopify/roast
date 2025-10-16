# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  # ...
end

execute do
  chat(:lake) { "What is the deepest lake?" }
end
