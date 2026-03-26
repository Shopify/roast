# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :pi
    model "anthropic/claude-haiku-4-5-20251001"
    append_system_prompt "Always respond in haiku form"
    show_prompt!
    dump_raw_agent_messages_to "tmp/pi-messages.log"
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
