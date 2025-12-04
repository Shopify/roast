# Chapter 8: Iterative Workflows

Learn how to create iterative workflows with the `repeat` cog, which executes a named scope repeatedly until a condition
is met. Unlike `map` which processes a collection holding a fix number of items, `repeat` continues indefinitely until
it hits a specified maximum number of iterations or you explicitly stop it with `break!`.

## The `repeat` Cog

The `repeat` cog executes a named execute scope repeatedly, where the output of each iteration becomes the input to the
next:

```ruby
execute(:process) do
  ruby(:step_increment) do |_, value, index|
    new_value = value + index
    puts "Current value: #{new_value}"
    new_value
  end

  ruby { break! if ruby!(:step_increment).value >= 12 }

  outputs { ruby!(:step_increment).value }
end

execute do
  repeat(:loop, run: :process) { 0 } # Start with initial value 0

  ruby do
    puts "Final value: #{repeat!(:loop).value}"
  end
end
```

Each iteration receives two parameters:

1. The **value** from the previous iteration (or the initial value for the first iteration)
2. The **index** starting at 0 (or a custom `initial_index`)

Key differences from `map`:

- `repeat` continues until you call `break!` (or hit the specified maximum number of iterations)
- Each iteration's output becomes the next iteration's input (iterative transformation)
- `map` processes independent items; `repeat` builds up a result iteratively

## Maximum Iteration Limit

You can specify the optional `max_iterations` attribute on the input value of the `repeat` cog to set a limit
on the number of loop iterations that can run. By default, the value of this attribute is `nil`, and the loop
will be allowed to run forever, until explicitly terminated from within.

## Breaking Out of Loops

Use `break!` to terminate the loop. Once `break!` is called, no more iterations will run.
Also, the cog in which you call `break!` will not run, and no subsequent cogs in that iteration will run either.
It is often cleanest to call `break!` in a `ruby` cog at the end of the scope, that only performs a check for the
termination condition(s), but you can call it anywhere that makes sense.

NOTE: the `outputs` block will __always__ run, even if you call `break!` earlier in the scope.

```ruby
execute(:find_threshold) do
  chat(:analyze) do |_, number|
    "Is #{number} greater than 50? Answer yes or no."
  end

  ruby do
    response = chat!(:analyze).response
    break! if response.downcase.include?("yes")
  end

  outputs { |_, number| number + 10 }
end

execute do
  repeat(:search, run: :find_threshold) { 0 }

  ruby do
    puts "Stopped at: #{repeat!(:search).value}"
  end
end
```

## Skipping to the Next Iteration

Use `next!` to skip the rest of the current iteration and immediately start the next one:

```ruby
execute(:process_numbers) do
  ruby(:check) do |_, _, index|
    # Skip processing for multiples of 3
    if index % 3 == 0
      puts "  Skipping every third 3 iteration"
      next!
    end
    puts "Processing #{index}"
  end

  ruby(:double) do |_, value|
    result = value * 2
    puts "  Doubled to #{result}"
    result
  end

  ruby { |_, _, index| break! if index >= 10 }

  outputs { ruby!(:double).value }
end

execute do
  repeat(run: :process_numbers) { 1 }
end
```

When `next!` is called, the remaining cogs in that iteration are skipped, but the `outputs` block will still run, to
generate the input value for the next iteration.

## Accessing Iteration Results

Access specific iterations or the final result:

```ruby
execute do
  repeat(:loop, run: :process) { 0 }

  ruby do
    # Get value directly from the final iteration's output block
    final = repeat!(:loop).value
    puts "Final result: #{final}"

    # Access specific iterations
    first = from(repeat!(:loop).first)
    last = from(repeat!(:loop).last)
    third = from(repeat!(:loop).iteration(2))

    puts "First iteration: #{first}"
    puts "Last iteration: #{last}"
    puts "Third iteration: #{third}"
    
    # Access specific cogs in specific iterations
    answer = from(repeat!(:loop).iteration(-2)) { chat!(:question).text }
    puts "Second-to-last answer: #{answer}"
  end
end
```

## Processing All Iterations

Use `.results` with `collect` or `reduce` to process all iteration outputs:

```ruby
execute do
  repeat(:loop, run: :calculate) { 1 }

  ruby do
    # Collect all intermediate values
    all_values = collect(repeat!(:loop).results) do
      ruby!(:calculate).value
    end
    puts "All values: #{all_values.inspect}"

    # Sum all iterations
    total = reduce(repeat!(:loop).results, 0) do |sum|
      sum + ruby!(:calculate).value
    end
    puts "Sum of all iterations: #{total}"
  end
end
```

## The `outputs` Block

The `outputs` block determines what value gets passed to the next iteration. It always runs, even on an iteration where
`break!` or `next!` is called:

```ruby
execute(:accumulate) do
  ruby(:add) do |_, sum, index|
    sum + index
  end

  ruby { |_, _, index| break! if index >= 5 }

  # This runs even on the final iteration (when break! is called)
  outputs { ruby!(:add).value }
end

execute do
  repeat(run: :accumulate) { 0 }

  ruby do
    # The final value includes the computation from the iteration where break! was called
    puts "Final sum: #{repeat!(:accumulate).value}"
  end
end
```

## Custom Starting Index

Customize where iteration indices start:

```ruby
execute do
  repeat(run: :process) do |my|
    my.value = 100
    my.index = 10 # Start counting from 10
  end

  ruby do
    puts "Final: #{repeat!.value}"
  end
end
```

## Running the Workflows

Try these examples to see `repeat` in action:

```bash
# Basic iterative transformation
bin/roast execute --executor=dsl dsl/tutorial/08_iterative_workflows/basic_repeat.rb

# Using break! to terminate based on conditions
bin/roast execute --executor=dsl dsl/tutorial/08_iterative_workflows/conditional_break.rb
```
