# Chapter 7: Processing Collections

Learn how to process arrays and other collections with the `map` cog, which applies a named execute scope to each item
in a collection.

## The `map` Cog

The `map` cog executes a named execute scope (defined with `execute(:name)`) for each item in a collection:

```ruby
execute(:process_item) do
  chat(:analyze) do |_, item|
    "Analyze this item: #{item}"
  end
end

execute do
  map(run: :process_item) { ["item1", "item2", "item3"] }
end
```

The scope receives each item as its value parameter, just like with the `call` cog.

## Collecting Results

Use `collect` to gather outputs from all iterations into an array:

```ruby
# Get all final outputs
results = collect(map!(:process_items))

# Transform outputs with a block, with access to the original item and its index in the source collection
results = collect(map!(:process_items)) do |output, item, index|
  { original_item: item, result_text: output.text, index: }
end

# Access other cog outputs from within each iteration
sessions = collect(map!(:process_items)) do
  chat!(:analyze).session
end
```

## Reducing Results

Use `reduce` to combine outputs into a single value:

```ruby
# Sum all outputs
# The second argument to `reduce` is the initial value for the accumulator. It is required.
total = reduce(map!(:calculate_scores), 0) do |sum, output|
  # the block given to `reduce` should return the new value of the accumulator at each step
  sum + output
end

# Build a hash
results = reduce(map!(:process_items), {}) do |hash, output, item, index|
  # returning nil will skip this item; it will not reset the accumulator to nil
  hash.merge(item => output) unless output.text.include?("failure")
end
```

## Parallel Execution

By default, `map` runs iterations serially. Configure parallel execution for the `map` cog in the `config` block.
Roast uses fibers for efficient asynchronous operation.

```ruby
config do
  map do
    parallel(3) # Run up to 3 iterations concurrently for all `map` cogs
  end

  map(:unlimited) do
    parallel! # Run all iterations in parallel for a specific `map` cog
  end
end
```

Results from `collect` and `reduce` are always returned in the original order, regardless of completion order.

## Accessing Specific Iterations

Access the output from a specific iteration using `.iteration(index)`.
This is convenient shorthand to avoid having to `collect` all the outputs when you only want one
in a particular situation.

```ruby
# Get output from third iteration (index 2)
result = from(map!(:process_items).iteration(2))

# Access first and last iterations
first_result = from(map!(:process_items).first)
last_result = from(map!(:process_items).last)

# Use with a block to access specific cogs
result = from(map!(:process_items).iteration(2)) do
  chat!(:analyze).response
end
```

## Working with Indices

Scopes called by `map` receive the iteration index as a third parameter:

```ruby
execute(:process_with_index) do
  chat(:numbered) do |_, item, index|
    "Process item #{index}: #{item}"
  end
end

execute do
  # Default: indices start at 0
  map(run: :process_with_index) { ["a", "b", "c"] }

  # Custom starting index
  map(run: :process_with_index) do |my|
    my.items = ["a", "b", "c"]
    my.initial_index = 1 # Start counting from 1
  end
end
```

Technically, because you can call a scope with `call` just as well as `map`, the third `index` argument
will always be present. When you invoke a scope with `call`, the index will be 0 by default. You can also override
the index value for an individual call invocation, to simulate processing one item from the middle of a collection.

```ruby
call(run: :some_scope) do |my|
  my.value = "some data"
  my.index = 3
end
```

## Running the Workflows

Try these examples to see `map` in action:

```bash
# Basic map with collect, reduce, and accessing specific iterations
bin/roast execute --executor=dsl dsl/tutorial/07_processing_collections/basic_map.rb

# Parallel execution
bin/roast execute --executor=dsl dsl/tutorial/07_processing_collections/parallel_map.rb
```

## What's Next?

In the next chapter, you'll learn about iterative workflows with the `repeat` cog: an easy way to execute a set of
steps repeatedly until a condition is met.

But first, experiment with `map` to process collections and try different parallel execution strategies!
