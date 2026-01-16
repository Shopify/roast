# Chapter 3: Targets and Parameters

In the previous chapters, you learned how to create workflows and chain cogs together. Now you'll learn how to make your
workflows more flexible by accepting targets and custom parameters from the command line.

## What You'll Learn

- How to pass targets (files, URLs, etc.) to workflows
- How to use `target!` for single-target workflows
- How to access multiple targets with `targets`
- How to pass custom arguments with `args`
- How to pass key-value parameters with `kwargs`
- How to check for the presence of arguments and parameters

## Workflow Targets

Targets are inputs that you want your workflow to process—files, URLs, or any other data. They're specified on the
command line after your workflow file path:

```bash
bin/roast execute workflow.rb https://example.com
bin/roast execute workflow.rb README.md
bin/roast execute workflow.rb src/*.rb
bin/roast execute workflow.rb Gemfile Gemfile.lock
```

Shell globs are expanded automatically, so `src/*.rb` will pass all Ruby files in the `src/` directory.

### Accessing a Single Target

Use `target!` when your workflow expects exactly one target:

```ruby
execute do
  cmd(:fetch) do
    "curl -sL #{target!}"
  end

  ruby do
    puts "Target: #{target!}"
    puts "Content length: #{cmd!(:fetch).out.length} bytes"
  end
end
```

Run it with:
```bash
bin/roast execute workflow.rb https://example.com
```

**Important:** `target!` raises an error if zero or multiple targets are provided. Use it when your workflow is
designed to process exactly one target.

### Accessing Multiple Targets

Use `targets` (plural) when your workflow can handle any number of files:

```ruby
execute do
  ruby do
    if targets.empty?
      puts "No files provided"
    else
      puts "Processing #{targets.length} files:"
      targets.each { |file| puts "  - #{file}" }
    end
  end
end
```

The `targets` method always returns an array, which will be empty if the workflow is invoked with no targets specified.

## Custom Arguments

Custom arguments let you pass additional data to your workflows. They come after `--` on the command line:

```bash
bin/roast execute workflow.rb -- hello world
```

### Simple Arguments (args)

Simple word tokens become arguments, accessible as symbols:

```ruby
execute do
  ruby do
    puts "Arguments: #{args.inspect}"  # [:hello, :world]

    # Check if a specific argument is present
    if arg?(:save_data)
      puts "Will save incremental data files"
    end
  end
end
```

Run it with:
```bash
bin/roast execute workflow.rb -- hello world
```
Or:
```bash
bin/roast execute workflow.rb -- save_data something_else
```

### Key-Value Arguments (kwargs)

Use `key=value` format for key-value parameters:

```ruby
execute do
  ruby do
    # Check if a kwarg is present
    if kwarg?(:format)
      puts "Format: #{kwarg(:format)}"
    end

    # Access all kwargs
    puts "All kwargs: #{kwargs.inspect}"

    # Access a specific kwarg (returns nil if not present)
    name = kwarg(:name)
    puts "Name: #{name}"

    # Access with error if missing
    email = kwarg!(:email)  # raises error if 'email' not provided
    puts "Email: #{email}"
  end
end
```

Run it with:
```bash
bin/roast execute workflow.rb -- name=Alice format=json
```
Or:
```bash
bin/roast execute workflow.rb -- name=Alice email=alice@example.net
```

**Notes:**
- Kwarg keys are parsed as symbols
- Kwarg values are always strings
- Simple words (without `=`) become args, not kwargs

## Combining Targets and Arguments

You can use targets and custom arguments together:

```bash
bin/roast execute workflow.rb file1.rb file2.rb -- save_data format=summary
```

In your workflow:

```ruby
execute do
  ruby do
    puts "Processing #{targets.length} files"
    puts "Save data: #{arg?(:save_data)}"
    puts "Format: #{kwarg(:format) || "default"}"
  end
end
```

## Accessing Parameters from Any Cog

All parameter accessors are available in any cog's input block:

```ruby
execute do
  chat(:analyze) do
    "Analyze this file: #{target!}"
  end

  agent(:process) do
    files = targets.join("\n")
    format = kwarg(:format) || "detailed"
    "Process these files and provide a #{format} report:\n#{files}) "
  end

  cmd(:grep_pattern) do
    pattern = kwarg!(:pattern)  # Error if not provided
    "grep '#{pattern}' #{targets.join(" ")}"
  end
end
```

## Running the Workflows

To run the examples in this chapter:

```bash
# Single target workflow (with a URL)
bin/roast execute tutorial/03_targets_and_params/single_target.rb https://example.com
```

```bash
# Multiple targets with arguments
bin/roast execute tutorial/03_targets_and_params/multiple_targets.rb \
  Gemfile Gemfile.lock -- save_data format=summary
```

## Try It Yourself

1. **Single target processing** - Run the single_target workflow with different URLs
2. **Multiple files** - Use shell globs to pass multiple files at once
3. **Add arguments** - Try different combinations of args and kwargs
4. **Error handling** - See what happens when you use `target!` with multiple files
5. **Mix and match** - Combine targets with different argument combinations

## Key Takeaways

- Use `target!` when your workflow expects exactly one file/url/etc. (errors otherwise)
- Use `targets` to access an array of all targets (can be empty)
- Custom arguments come after `--` on the command line
- Simple words become `args` (as symbols)
- `key=value` pairs become `kwargs` (keys as symbols, values as strings)
- Use `arg?(:name)` to check if an argument is present
- Use `kwarg(:name)` to get a kwarg value (returns nil if missing)
- Use `kwarg!(:name)` to require a kwarg (errors if missing)
- All accessors work in any cog's input block

## What's Next?

In the next chapter, you'll learn about configuration options: how to fine-tune cog behavior, control what gets
displayed, and set up different models for different tasks.

But first, experiment with targets and parameters to see how they make your workflows more flexible and reusable!
