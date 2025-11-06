# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent do
    provider :claude
    model "haiku"
    # initial_prompt "Always respond in haiku form"
    show_prompt!
    dump_raw_agent_messages_to "tmp/claude-messages.log"
  end
end

execute do
  agent { "Tell me about the git history of this project" }
end
