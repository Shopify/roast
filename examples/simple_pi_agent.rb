# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :pi
    model "sonnet"
    append_system_prompt "Always respond concisely in one sentence"
    show_prompt!
    dump_raw_agent_messages_to "tmp/pi-messages.log"
  end
end

execute do
  agent { "What is the capital of France?" }
end
