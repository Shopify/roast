# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent do
    provider :claude
    model "haiku"
    initial_prompt "Always respond in haiku form"
    show_prompt!
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
