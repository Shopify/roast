# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
end

execute do
  repeat(:loop, run: :loop_body) { 7 }

  ruby do
    # You can access the final output value of a `repeat` cog directly
    result = repeat!(:loop)
    puts "Ultimate Loop Result: #{result.value}"
  end

  ruby do
    puts "---"
    # You can also access the final result, or individual cog results, of any specific iteration
    # In the same manner as you would use `from` to access the results of a single `call` invocation.
    puts "First Iteration Result: #{from(repeat!(:loop).first)}"
    puts "Final Iteration Result: #{from(repeat!(:loop).last)}"
    puts "Second-to-last Iteration Result: #{from(repeat!(:loop).iteration(-2))}"
    # NOTE: accessing a specific iteration will raise an IndexException if the requested index is out of bounds
    # for the number of iterations that ran.
  end

  ruby do
    puts "---"
    # You can access the results of all iterations in the same manner as you would use `collect` or `reduce`
    # to access the complete results of a `map` invocation.
    puts "All :add cog outputs: #{collect(repeat!(:loop).results) { ruby!(:add).value }}"
    puts "Sum of :add cog output: #{reduce(repeat!(:loop).results, 0) { |acc| acc + ruby!(:add).value }}"
  end
end

execute(:loop_body) do
  # on each loop iteration, the input value provided will be the output value of the previous iteration
  # the initial value will be what was provided when `repeat` was called in the outer scope.
  ruby(:add) do |_, num, idx|
    new_num = num + idx
    s = "iteration #{idx}: #{num} + #{idx} -> #{new_num}"
    puts s
    new_num
  end

  ruby { |_, _, idx| break! if idx >= 3 }

  # The value provided to `outputs` will be the input value for the next iteration
  # On the final iteration, it will also be the `repeat` cog's own output value
  outputs { ruby!(:add).value }
end
