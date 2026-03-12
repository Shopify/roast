# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  agent do
    provider :claude
    model "haiku"
    show_prompt!
    dump_raw_agent_messages_to "tmp/claude-messages2.log"
  end
end

execute do
  agent(:multi_step) do
    [
      "What is 2+2?",
      "Now multiply that by 3",
      "Now subtract 5"
    ]
  end
  ruby do
    answer = agent!(:multi_step).integer!
    puts "((2 + 2) * 3) - 5 = #{answer}"
  end
end
