# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This workflow demonstrates conditional execution using skip! and the ? accessor.
# It checks a random number and runs different steps based on whether it's even or odd.

config do
  cmd do
    display!
  end
end

execute do
  # Generate a random number
  cmd(:random_number) { "echo $RANDOM" }

  # This step only runs if the number is even
  cmd(:process_even) do
    number = cmd!(:random_number).text.to_i
    skip! if number.odd?
    "echo 'Processing even number: #{number}'"
  end

  # This step only runs if the number is odd
  cmd(:process_odd) do
    number = cmd!(:random_number).text.to_i
    skip! if number.even?
    "echo 'Processing odd number: #{number}'"
  end

  # This step always runs and reports which path was taken
  cmd do |my|
    my.command = "echo"

    # Use the ? accessor to check which steps ran
    my.args << if cmd?(:process_even)
      "Even path executed"
    elsif cmd?(:process_odd)
      "Odd path executed"
    else
      "Neither path executed (unexpected!)"
    end
  end

  # Demonstrate using non-bang accessor
  ruby do
    puts "\n" + "=" * 70
    puts "CONDITIONAL EXECUTION RESULTS"
    puts "=" * 70

    number = cmd!(:random_number).out.to_i
    puts "Random number was: #{number}"

    # Non-bang accessor returns nil if cog didn't run
    puts "Even result: #{cmd(:process_even) || "n/a"}"
    puts "Odd result: #{cmd(:process_odd) || "n/a"}"

    puts "=" * 70 + "\n"
  end
end
