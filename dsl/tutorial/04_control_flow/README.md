# Chapter 4: Control Flow

In previous chapters, you learned how to chain cogs together and configure them. Now you'll learn how to create
dynamic workflows that adapt based on conditions: skipping steps when needed, handling failures gracefully, and
checking whether steps actually ran.

## What You'll Learn

- How to conditionally skip cogs with `skip!`
- How to handle cog failures with `fail!` and `no_abort_on_failure!`
- How command failures work and how to control them
- How to check if a cog ran successfully with three different accessors
- The difference between `!`, `?`, and non-bang accessors

## Conditional Execution with skip!

Use `skip!` inside a cog's input block to conditionally skip that cog:

```ruby
execute do
  cmd(:check_status) { "curl https://api.example.com/status" }

  cmd(:notify) do
    status = cmd!(:check_status).out
    skip! if status.include?("healthy")
    "echo 'Service needs attention!'"
  end
end
```

When `skip!` is called, the cog immediately stops executing and is marked as skipped. Skipped cogs won't have
output and can be detected using the `?` accessor.

## Checking if Cogs Ran

You have three ways to access cog outputs, each with different behavior:

- `cog!(:name)` - Returns output, raises error if cog didn't run yet, was skipped, or failed
- `cog?(:name)` - Returns `true` if cog ran and completed successfully, `false` otherwise
- `cog(:name)` - Returns output or `nil` if cog didn't run yet, was skipped, or failed

```ruby
execute do
  chat(:analyze) do
    data = cmd(:fetch_data).out # Returns nil if fetch_data was skipped
    skip! unless data
    "Analyze this: #{data}"
  end

  ruby do
    if chat?(:analyze)
      puts "Analysis completed: #{chat!(:analyze).response}"
    else
      puts "Analysis was skipped"
    end
  end
end
```

The `?` accessor is particularly useful for checking whether optional steps ran.

## Handling Failures

Cogs can fail in two ways: by explicitly calling `fail!`, or by encountering errors during execution (like a command
returning a non-zero exit code). By default, any cog failure will also abort the entire workflow.

### Explicit Failure with fail!

Use `fail!` to terminate a cog when conditions prevent successful execution:

```ruby
execute do
  agent(:process) do |my|
    file = Pathname.new("my/data/file.json")
    fail! unless file.exist?
    my.prompt = "Process this file: #{file.realpath}"
  end
end
```

### Command Failures

By default, the `cmd` cog automatically fails when a command returns a non-zero exit status.
And also by default, when a cog fails the entire workflow is aborted.
You can control both aspects of this behavior:

```ruby
config do
  cmd(:risky) do
    # This command might fail, but continue the workflow anyway if it does
    no_abort_on_failure!
  end
  cmd(:grep) do
    # This command might exit with a non-zero status code, but that doesn't represent a failure for it
    no_fail_on_error!
  end
end

execute do
  cmd(:risky) { "[ $RANDOM -gt 30000 ] && echo 'it worked!'" } # This command will probably fail

  # We expect a non-zero exit code here as part of normal operations.
  # `grep` matching no lines does not represent a failure condition for our workflow.
  cmd(:grep) { "grep 'pattern' file.txt" }

  ruby do
    puts cmd?(:risky) ? "Risky command succeeded" : "Risky command failed"
    puts "Grep matched #{cmd(:grep).lines.length} lines"
  end
end
```

Use `no_abort_on_failure!` to let the workflow continue even when a cog fails. The non-bang and `?` accessors let you
check the result and handle failures gracefully.

Use `no_fail_on_error!` with the `cmd` cog specifically to indicate that a non-zero status code should not
be considered a failure.

## Running the Workflows

To run the examples in this chapter:

```bash
# Conditional execution example
bin/roast execute --executor=dsl dsl/tutorial/04_control_flow/conditional_execution.rb
```

```bash
# Handling failures example
bin/roast execute --executor=dsl dsl/tutorial/04_control_flow/handling_failures.rb
```

## Try It Yourself

1. **Add conditions** - Use `skip!` to create optional workflow steps
2. **Check outcomes** - Use the `?` accessor to branch based on whether steps ran
3. **Handle failures** - Use `fail!` for validation and the non-bang accessor for recovery
4. **Combine approaches** - Mix conditional execution with the techniques from previous chapters

## Key Takeaways

- Use `skip!` to conditionally skip cogs based on runtime conditions
- Use `fail!` to explicitly terminate cogs that can't complete successfully
- Commands automatically fail on non-zero exit status (configurable with `no_fail_on_error!`)
- Use `no_abort_on_failure!` to continue workflows even when cogs fail
- Use `cog?(:name)` to check if a cog ran successfully
- Use `cog(:name)` (non-bang) to safely access outputs that might not exist
- Use `cog!(:name)` when you expect the cog to have run successfully
- Control flow makes workflows dynamic and adaptive

## What's Next?

In the next chapter, you'll learn about processing collections: using `map` to apply operations across multiple items
and building workflows that handle batches of data.

But first, experiment with control flow to create workflows that adapt to different conditions!
