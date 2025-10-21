# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent(:foo) do
    provider(:claude)
  end
end

execute do
  agent(:foo) { "Say hi" }
end
