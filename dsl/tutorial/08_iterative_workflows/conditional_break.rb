# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat { display! }
end

execute(:guess_number) do
  ruby { |_, _, index| puts "\n--- Iteration #{index} ---" }

  chat(:make_initial_guess) do |_, _, index|
    skip! unless index == 0

    <<~PROMPT
      I'm thinking of a number between 1 and 100.
      Take a guess! Respond with just the number.
    PROMPT
  end

  chat(:make_guess) do |my, state, index|
    skip! if index == 0

    guess, session, target = state.values_at(:guess, :session, :target)
    break! if guess == target

    my.session = session
    my.prompt = "Too #{guess > target ? "high" : "low"}. Guess again"
  end

  outputs do |_, target|
    result = chat(:make_guess) || chat!(:make_initial_guess)
    { guess: result.integer, session: result.session, target: }
  end
end

execute do
  ruby do
    fail! "Target number out of range" if target!.to_i < 1 || target!.to_i > 100

    puts "=== Number Guessing Game ==="
    puts "Target number: #{target!} (hidden from the LLM)\n"
  end

  repeat(:guessing, run: :guess_number) do |my|
    my.value = target!.to_i
    my.max_iterations = 7
  end

  ruby do
    iteration_count = collect(repeat!(:guessing).results).length

    puts "\n=== Game Complete ==="
    puts "Found the number in #{iteration_count} guesses!"
  end
end
