# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
end

execute do
  # Repeat the 'check_random' executor until we get the result we want
  repeat(:loop_result, run: :check_random)

  # Print the final result
  cmd(:final_output) do
    "echo 'Loop completed successfully!'"
  end
end

execute(:check_random) do
  # Generate a random number
  ruby(:random_number) do
    rand(1..10)
  end

  # Print the number
  cmd(:print_number) do
    number = ruby!(:random_number).value
    "echo 'Generated number: #{number}'"
  end

  # Check if we should break (when we get a number >= 7)
  ruby(:check_break) do
    number = ruby!(:random_number).value
    if number >= 7
      puts "Got #{number}! Breaking out of loop."
      break!
    else
      puts "Got #{number}, continuing..."
    end
    number
  end
end
