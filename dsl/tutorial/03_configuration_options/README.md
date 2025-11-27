# Chapter 3: Configuration Options

In previous chapters, you learned the basics of creating workflows and chaining cogs together. Now you'll learn how to
configure cogs to control their behavior, use different models for different steps, and manage what gets displayed
during execution.

## What You'll Learn

- How to configure models and providers
- The difference between global and per-step configuration
- How to use different models for different steps
- How to control what gets displayed during execution
- Common model parameters like temperature

## Global Configuration

The `config` block at the top of your workflow sets defaults for all cogs of a given type:

```ruby
config do
  chat do
    model "gpt-4o-mini"
    provider :openai
  end
end

execute do
  # All chat cogs will use gpt-4o-mini unless overridden
  chat(:first) { "Analyze this data..." }
  chat(:second) { "Summarize that analysis..." }
end
```

Both chat cogs will use `gpt-4o-mini` from OpenAI because that's the global default you specified in the `config` block.

### Configuring Multiple Cog Types

You can set defaults for different cog types in the same config block:

```ruby
config do
  chat do
    model "gpt-4o-mini"
    provider :openai
  end

  agent do
    model "claude-3-5-haiku-20241022"
    provider :claude
  end
end
```

Now all `chat` cogs use "gpt-4o-mini" and all `agent` cogs use Claude Code with the "haiku" model (unless you override
them individually).

## Per-Step Configuration

Override global configuration for specific named cogs by configuring them explicitly in the `config` block:

```ruby
config do
  # Global default for all chat cogs
  chat do
    model "gpt-4o-mini"
    provider :openai
  end

  # Override for a specific named cog
  chat(:complex_task) do
    model "gpt-5"
    # any options you don't set here (we're not specifying 'provider' again, for instance) will be inherited from
    # the global config, or will use Roast's default values.
  end
end

execute do
  # Uses global config (gpt-4o-mini)
  chat(:simple_task) { "Categorize this: #{data}" }

  # Uses the specific override (gpt-5)
  chat(:complex_task) { "Perform deep analysis of this data: #{data}" }
end
```

The `:simple_task` cog uses the configured global default, but `:complex_task` has its own configuration that overrides.

### Pattern-Based Configuration

You can also configure multiple cogs at once using a regex pattern:

```ruby
config do
  chat do
    model "gpt-4o-mini"
    provider :openai
  end

  # All cogs with names matching this pattern use gpt-4o
  chat(/analyze_/) do
    model "gpt-4o"
  end
end

execute do
  chat(:extract_data) { "..." } # Uses gpt-4o-mini
  chat(:analyze_deep) { "..." } # Uses gpt-4o (matches pattern)
  chat(:analyze_trends) { "..." } # Uses gpt-4o (matches pattern)
end
```

This is useful when you have multiple similar cogs that need the same configuration.

## Display Options

Control what gets printed during workflow execution using display methods in your `config` block:

Different cogs have different display options. For the `chat` and `agent` cogs, you can control the display of
the prompt, response, usage statistics, and (for the agent cog) incremental progress messages.

- `show_prompt!` / `no_show_prompt!` - Control prompt display
- `show_response!` / `no_show_response!` - Control response display
- `show_stats!` / `no_show_stats!` - Control statistics display

For the `cmd` cog, you can control the display of standard output and standard error.

- `show_stdout!` / `no_show_stdout!` - Control stdout display
- `show_stderr!` / `no_show_stderr!` - Control stdout display

And for all cog types, you can quickly apply some typical configurations

- `display!` - Show everything (prompt, response, stats / standard output and error / etc.)
- `no_display!` / `quiet!` - Hide everything

```ruby
config do
  chat do
    no_show_response! # Hide all responses by default
  end

  chat(:summarize) do
    show_response! # But show the final summary
  end
end
```

This is useful for hiding intermediate steps while showing only the final output. See `control_display_and_temperature.rb` for more examples.

## Model Parameters

Fine-tune model behavior with additional parameters:

### Temperature

Controls randomness (0.0-1.0, where 0.0 = deterministic, 1.0 = more random):

```ruby
config do
  chat(:creative_writing) do
    temperature(0.9)
  end

  chat(:data_extraction) do
    temperature(0.0)
  end
end

execute do
  chat(:creative_writing) { "Write a creative story about: #{topic}" }
  chat(:data_extraction) { "Extract structured data from: #{text}" }
end
```

## Running the Workflows

To run the examples in this chapter:

```bash
# Simple configuration example
bin/roast execute --executor=dsl dsl/tutorial/03_configuration_options/simple_config.rb
```

```bash
# Configuring multiple parameters for multiple steps
bin/roast execute --executor=dsl dsl/tutorial/03_configuration_options/control_display_and_temperature.rb
```

## Try It Yourself

1. **Experiment with models** - Try different models for the same prompt and compare results
2. **Adjust temperature** - See how temperature affects creative vs factual outputs
3. **Control display** - Hide intermediate steps and only show final output
4. **Mix providers** - Use OpenAI for some steps and Anthropic for others
5. **Use patterns** - Try pattern-based configuration to configure multiple cogs at once

## Key Takeaways

- Use `config` blocks to set global defaults for cog types
- Override global config by naming specific cogs in the `config` block: `chat(:name) do ... end`
- Use pattern-based config with regex: `chat(/pattern/) do ... end`
- Use display methods like `show_prompt!` and `no_show_response!` to control what gets printed
- Different cog types can use different default configurations

## What's Next?

In the next chapter, you'll learn about control flow: how to conditionally skip steps, handle failures, and create
dynamic workflows that adapt based on intermediate results.

But first, experiment with different configurations to understand how they affect workflow behavior!
