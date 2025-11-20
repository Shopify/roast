# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This example demonstrates using repeat with state accumulation
# by collecting the results from each iteration

config do
  cmd { print_all! }
end

execute do
  # Repeat the 'generate_number' executor until we get a number >= 8
  repeat(:loop_result, run: :generate_number)

  # Collect all the numbers that were generated
  ruby(:all_numbers) do
    collect(repeat!(:loop_result)) { ruby!(:random_number).value }
  end

  # Print the results
  cmd(:summary) do
    numbers = ruby!(:all_numbers).value
    iterations = repeat!(:loop_result).iterations
    broke = repeat!(:loop_result).broke?
    "echo 'Generated #{iterations} numbers: #{numbers.join(", ")}' && echo 'Broke: #{broke}'"
  end
end

execute(:generate_number) do
  # Generate a random number
  ruby(:random_number) do
    rand(1..10)
  end

  # Print the number
  cmd(:print_number) do
    number = ruby!(:random_number).value
    "echo 'Generated: #{number}'"
  end

  # Check if we should break (when we get a number >= 8)
  ruby(:check_break) do
    number = ruby!(:random_number).value
    break! if number >= 8
    number
  end
end
