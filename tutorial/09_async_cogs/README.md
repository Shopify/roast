# Chapter 9: Asynchronous Cogs

Learn how to run cogs asynchronously in the background while other work continues. This is different from `map` with
parallel execution, which can run multiple invocations of an execution scope in parallel, each processing a different
input. Async cogs let you run all sorts of independent tasks concurrently, __within the same execution scope__ without
waiting for one task to complete before starting another.

## What Are Async Cogs?

By default, cogs run synchronously: each cog must complete before the next one starts. With async cogs, you can kick off
long-running tasks in the background and continue with other work immediately.

```ruby
config do
  agent(:analyze_code) { async! }
end

execute do
  # This agent starts running in the background
  agent(:analyze_code) do
    "Analyze the Ruby files in src/ for code quality issues. List the top three issues."
  end

  # This starts immediately without waiting for the agent to finish
  chat(:draft_email) do
    "Draft a brief status update email about the current sprint"
  end

  # This blocks until the agent completes, then uses its output
  chat(:finish_email) do |my|
    my.session = chat!(:draft_email).session
    my.prompt = <<~PROMPT
      "Update the status email with a summary of the issues we'll tackle next week:
      #{agent!(:analyze_code).text}"
    PROMPT
  end
end
```

## Key Differences from Parallel Map

- **Async cogs**: Run different, independent tasks concurrently in the same scope (e.g., analyze code + draft email)
- **Parallel map**: Apply the same operation to multiple items concurrently (e.g., process 10 files in parallel), each in their own scope

Use async cogs when you have separate tasks that can happen at the same time. Use parallel map when you're processing a
collection.

## Configuring Async Cogs

Configure cogs to run asynchronously in the `config` block:

```ruby
config do
  # Make specific cog async
  agent(:background_task) { async! }

  # Make all agent cogs async
  agent { async! }

  # Pattern-based configuration
  agent(/analyze_/) { async! }

  # Override a more general config to make a cog explicitly synchronous (this is the default)
  chat(:critical_step) { no_async! }
end
```

## How Async Execution Works

When an async cog is invoked:

1. It starts running in the background
2. The next cog starts immediately (doesn't wait)
3. If you try access the async cog's output from a later cog, that will block until the async cog completes
4. The workflow doesn't exit until all async cogs have finished
5. A named execute scope doesn't complete until all async cogs within it have finished 

```ruby
config do
  agent { async! }
end

execute do
  agent(:task1) { "Read and summarize README.md" }
  agent(:task2) { "Count lines of code in src/" }
  agent(:task3) { "List all TODO comments" }

  # Accessing outputs blocks until each completes
  ruby do
    puts "\nTask 1: #{agent!(:task1).response}"
    puts "\nTask 2: #{agent!(:task2).response}"
    puts "\nTask 3: #{agent!(:task3).response}"
  end
end
```

## Accessing Async Cog Outputs

All three accessor patterns (the `!`, `?` and normal cog methods) work with async cogs and all will block if needed:

```ruby
config do
  agent { async! }
end

execute do
  agent(:background) { "Long running task" }

  ruby do
    # All of these block until the async cog completes:

    # Check if it ran (blocks)
    if agent?(:background)
      puts "Completed!"
    end

    # Get output or nil (blocks)
    result = agent(:background)

    # Get output or raise error (blocks)
    result = agent!(:background)
  end
end
```

## Real-World Example: Parallel Code Analysis

Run multiple independent analyses concurrently:

```ruby
config do
  agent { async! }
end

execute do
  # All three start immediately
  agent(:security) do
    "Review files in src/ for security vulnerabilities"
  end

  agent(:performance) do
    "Identify performance bottlenecks in src/"
  end

  agent(:style) do
    "Check code style and formatting in src/"
  end

  # Collect results as they complete
  ruby do
    puts "\n=== Security Issues ==="
    puts agent!(:security).response

    puts "\n=== Performance Issues ==="
    puts agent!(:performance).response

    puts "\n=== Style Issues ==="
    puts agent!(:style).response
  end
end
```

## When to Use Async Cogs

**Good use cases:**

- Running multiple independent agent tasks that don't depend on each other
- Starting a long-running background task while doing other work
- Parallelizing unrelated API calls or file operations

**Not needed when:**

- Cogs already run fast enough sequentially
- Cogs depend on each other's outputs (they'll block anyway)
- You're processing a collection (use `map` with `parallel!` instead)

## Important Notes

- Async cogs use Ruby's fiber-based concurrency (efficient and lightweight)
- The workflow waits for all async cogs to complete before exiting
- Accessing an async cog's output blocks until that cog finishes
- All cog types (`agent`, `chat`, `cmd`, `ruby`, and even `call`, `map`, and `repeat`) can be async

## Running the Workflows

Try these examples to see async cogs in action:

```bash
# Basic async execution
bin/roast execute --executor=dsl dsl/tutorial/09_async_cogs/basic_async.rb

# Parallel analysis with multiple agents
bin/roast execute --executor=dsl dsl/tutorial/09_async_cogs/parallel_analysis.rb

# Synchronous barriers controlling execution order
bin/roast execute --executor=dsl dsl/tutorial/09_async_cogs/sync_barriers.rb
```
