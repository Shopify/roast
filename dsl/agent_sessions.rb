# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent do
    provider :claude
    model "haiku"
    dump_raw_agent_messages_to "tmp/claude-messages.log"
  end
end

execute do
  agent(:one) { "The magic word is 'pomegranate'" }
  agent(:two) do |my|
    my.session = agent!(:one).session
    "What is the magic word?"
  end
end
