# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  chat do
    model "gpt-4o-mini"
    provider :openai
    no_display!
  end

  map(:serial) do
    no_parallel! # Explicitly serial (this is the default)
  end

  map(:limited_parallel) do
    parallel(2) # Process up to 2 items concurrently
  end

  map(:unlimited_parallel) do
    parallel! # Process all items concurrently
  end
end

execute(:generate_fact) do
  chat(:fact) do |_, topic, index|
    <<~PROMPT
      Generate a brief, interesting fact (one sentence) about: #{topic}
      Label it as "Fact #{index}:"
    PROMPT
  end
end

execute do
  topics = ["Ruby", "Python", "JavaScript", "Go", "Rust"]

  # Serial execution (one at a time)
  map(:serial, run: :generate_fact) do |my|
    my.items = topics
    my.initial_index = 1
  end

  ruby do
    puts "\n=== Serial Execution ==="
    facts = collect(map!(:serial)) { chat!(:fact).response.strip }
    facts.each { |fact| puts fact }
  end

  # Limited parallelism (up to 2 concurrent)
  map(:limited_parallel, run: :generate_fact) do |my|
    my.items = topics
    my.initial_index = 1
  end

  ruby do
    puts "\n=== Limited Parallel Execution (max 2 concurrent) ==="
    facts = collect(map!(:limited_parallel)) { chat!(:fact).response.strip }
    facts.each { |fact| puts fact }
  end

  # Unlimited parallelism (all at once)
  map(:unlimited_parallel, run: :generate_fact) do |my|
    my.items = topics
    my.initial_index = 1
  end

  ruby do
    puts "\n=== Unlimited Parallel Execution ==="
    facts = collect(map!(:unlimited_parallel)) { chat!(:fact).response.strip }
    facts.each { |fact| puts fact }
    puts "\nNote: Results are always returned in original order, regardless of completion order."
  end
end
