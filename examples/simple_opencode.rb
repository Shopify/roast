# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :opencode
    model "anthropic/claude-haiku-4-5"
  end
end

execute do
  agent { "What is the world's largest mountain?" }
end
