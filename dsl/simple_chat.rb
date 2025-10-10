# typed: true
# frozen_string_literal: true
#: self as Roast::DSL::Executor

config do
  # ...
end

execute do
  chat(:lake) { "What is the deepest lake?" }
end
