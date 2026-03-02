# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This example demonstrates session management with the Pi coding agent.
# The first agent establishes a fact, and the second agent resumes
# from that session to recall it.

config do
  agent do
    provider :pi
    model "sonnet"
    dump_raw_agent_messages_to "tmp/pi-messages.log"
  end
end

execute do
  agent(:one) { "The magic word is 'pomegranate'" }
  agent(:two) do |my|
    my.session = agent!(:one).session
    "What is the magic word?"
  end
end
