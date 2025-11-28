# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat do
    model "gpt-4o-mini"
    no_display!
    show_stats!
  end
  chat(:recall_code) do
    model "gpt-4.1-nano"
  end
  agent do
    model "haiku"
    no_display!
    show_stats!
  end
  agent(:followup_question) do
    model "sonnet"
  end
end

execute do
  # First conversation turn - tell the LLM something
  chat(:introduce_topic) do
    <<~PROMPT
      I'm going to tell you a secret code word. Remember it for later.
      The secret code word is: "thunderbolt"

      Just respond with "OK, I'll remember that."
    PROMPT
  end

  ruby do
    puts "First turn: #{chat!(:introduce_topic).text}"
  end

  # Second turn - resume the session and ask about it
  chat(:recall_code) do |my|
    # Resume the previous conversation by passing the session
    # You can even resume with a different model that you used earlier in the session
    my.session = chat!(:introduce_topic).session
    my.prompt = "What was the secret code word I told you?"
  end

  ruby do
    puts "Second turn: #{chat!(:recall_code).text}"
  end

  # Third turn - continue the conversation further
  chat(:update_code) do |my|
    # Can resume from any previous step in the conversation chain
    my.session = chat!(:recall_code).session
    my.prompt = "The new code word is 'mermaid'"
  end

  # Fourth turn - resume from an earlier point
  chat(:resume_from_beginning) do |my|
    # Every time you resume from a particular previous session, a new session is forked.
    # You can always resume from that point again, without any new context being present.
    my.session = chat!(:introduce_topic).session
    my.prompt = "What is the current secret code word?"
  end

  ruby do
    puts "Third turn: #{chat!(:update_code).response}"
    # This will be the original word from the first turn
    puts "Fourth turn: #{chat!(:resume_from_beginning).response}"
  end

  # Example with agent cog - works the same way
  agent(:analyze_file) do
    "What files are in the current directory? Just list a few."
  end

  ruby do
    puts "\n--- Agent Session ---"
    puts "Agent response: #{agent!(:analyze_file).response}"
  end

  agent(:followup_question) do |my|
    # Resume the agent session
    my.session = agent!(:analyze_file).session
    "Pick one of those files and tell me what it is."
  end

  ruby do
    puts "Agent followup: #{agent!(:followup_question).response}"
  end
end
