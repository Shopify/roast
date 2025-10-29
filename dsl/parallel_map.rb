# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { display! }
  map(:words) do
    # By default, maximum parallelism is 1 and map executions will run synchronously
    # Calling `parallel` with a larger value will allow multiple map items to be run in parallel, up to the limit given
    # Calling `parallel!` or `parallel(0)` will allow unlimited parallelism, processing all map items in parallel
    parallel 3
  end
end

execute(:capitalize_a_word) do
  cmd(:to_upper) do |_, word, index|
    sleep(0.1) if index == 3 # "three" will be slow --> finishing second last
    sleep(0.2) if index == 1 # "one" will be slowest --> finishing last
    ["sh", "-c", "echo \"#{word}\" | tr '[:lower:]' '[:upper:]'"]
  end
end

execute do
  # Call a subroutine with `map`
  map(:words, run: :capitalize_a_word) do |my|
    my.items = ["one", "two", "three", "four", "five", "six"]
    my.initial_index = 1 # for convenience, just because our items begin with "one"
  end

  cmd do |my|
    my.command = "echo"
    # Regardless of the order in which the items were processed by a parallel map,
    # their results will always be provided to `collect` and `reduce` in the order in which they were given.
    my.args << collect(map!(:words)) { cmd!(:to_upper).out }.join(", ")
  end
end
