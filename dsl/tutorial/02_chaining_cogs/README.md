# Chapter 2: Chaining Cogs Together

In the previous chapter, you learned how to use a single chat cog. Now you'll learn how to chain multiple cogs together,
where the output of one step becomes the input to the next. This is where workflows become truly powerful.

## What You'll Learn

- How to name cogs so you can reference them
- How to access outputs from previous cogs
- How to chain cogs together to build multi-step workflows
- The difference between `agent` and `chat` cogs
- How to use the `ruby` cog for custom logic

## Naming Cogs

When you have multiple steps, you need to name them so you can reference their outputs. Give each cog a descriptive name
using a symbol:

```ruby
execute do
  chat(:analyze) { "Analyze this text..." }
  chat(:summarize) { "Summarize that analysis..." }
end
```

The name goes in parentheses after the cog type.

## Accessing Outputs

To access the output from a previous cog, reference it by name just like you defined it:

```ruby
execute do
  chat(:analyze) { "Analyze this: #{data}" }

  # Access the 'analyze' cog's output
  chat(:summarize) do
    analysis = chat(:analyze).response
    "Summarize this analysis: #{analysis}"
  end
end
```

This returns the cog's output, or `nil` if the cog didn't run (we'll learn about conditionally skipping steps in a later
lesson.

### Different Output Methods

Different cog types provide different types of output. Here are few highlights:

- `chat(:name).response` - The text response from a chat cog
- `agent(:name).response` - The text response from an agent cog
- `ruby(:name).value` - The return value from a ruby cog
- `cmd(:name).out` - The stdout from a command cog
- `cmd(:name).err` - The stderr from a command cog

Check out the documentation for each cog to see the other output values it can provide.

### Text Output

All cogs that produce textual output (`agent`, `chat`, and `cmd`) include some standard convenience methods to make
working with that output easy:

- `.text` - The output text with surrounding whitespace removed.
  Using `cmd(:name).text` is particularly useful in place of `cmd(:name).out`
  when you're expecting a single line of output and just want that value without
  a trailing newline.
- `.lines` - An array containing the individual lines of the output text, each with
  surrounding whitespace removed. `chat(:name).lines` is equivalent to
  `chat(:name).response.lines.map(&:strip)`
- `.json` - A hash parsed from the output text in JSON format, or `nil` if the text could not
  be parsed as valid JSON. `.json!` is equivalent, but will raise an exception if the
  parsing fails.

### Checking If a Cog Ran

Use the `?` suffix to check whether a cog ran:

```ruby
execute do
  chat do |my|
    result = if chat?(:optional_step)
      # It ran, safe to access
      chat(:optional_step).response
    else
      # It didn't run (maybe it was skipped)
      "No analysis available"
    end
    my.prompt = "Characterize this result: #{result}"
  end
end
```

### The `!` Suffix: Convenient Shorthand

When you're not intentionally skipping cogs, use the `!` suffix for convenient shorthand:

```ruby
execute do
  chat(:analyze) { "Analyze this: #{data}" }

  chat(:summarize) do
    analysis = chat!(:analyze).response # Raises error if analyze didn't run
    "Summarize this analysis: #{analysis}"
  end
end
```

The `!` suffix means "get this cog's output, and raise an error if it didn't run." This catches mistakes early. If you
try to access a cog that was accidentally skipped, or failed, you'll get a clear error right away, instead of a `nil`
result and a potential `NoMethodError` later on.

## The Agent Cog

The `agent` cog is similar to `chat`, but it runs locally and has access to your filesystem and the ability to use
a suite of local tools. Use `agent` when you need to read files, search code, or interact with your local environment:

```ruby
execute do
  agent(:code_review) do
    <<~PROMPT
      Read the Ruby files in the src/ directory and identify
      any potential security issues. Focus on input validation
      and data sanitization.
    PROMPT
  end
end
```

The `agent` cog is backed by a locally installed coding agent -- Anthropic's Claude Code is the default provider.
You'll need to have Claude Code installed and configured correctly for this cog to run.

### When to Use Agent vs Chat

- **Use `agent`** when you need to:
    - Read or write local files
    - Search through code
    - Run shell commands
    - Interact with your development environment

- **Use `chat`** when you need to:
    - Process data already in memory
    - Perform reasoning without file access
    - Generate text or analysis from provided context
    - Use less expensive/faster models for simple tasks

Both are equally capable of complex reasoning. The difference is **access**, not intelligence.

## The Ruby Cog

The `ruby` cog lets you run custom Ruby code within your workflow. Use it for data processing, formatting, or any logic
that doesn't need an LLM:

```ruby
execute do
  chat(:analyze) { "Analyze this data..." }

  ruby(:format_output) do
    analysis = chat!(:analyze).response

    # Custom formatting logic
    formatted = "=" * 60 + "\n"
    formatted += "ANALYSIS RESULTS\n"
    formatted += "=" * 60 + "\n"
    formatted += analysis + "\n"
    formatted += "=" * 60

    puts formatted

    # The return value is stored for later usage by other cogs
    { status: "complete", length: analysis.length }
  end
end
```

The ruby cog's return value is accessible via `ruby!(:name).value`.

## Data Flow Example

Here's how data flows through a typical workflow:

```ruby
execute do
  # Step 1: Select some files
  cmd(:recent_files_changes) do
    "git show --name-only HEAD~3..HEAD"
  end

  # Step 2: Agent analyzes the code
  agent(:security_review) do
    <<~PROMPT
      Review these recently changed files for security vulnerabilities:

      #{cmd!(:recent_files_changes).text}

      Identify specific issues and explain the risk.
    PROMPT
  end

  # Step 3: Chat creates a simple summary
  chat(:simple_summary) do
    review = agent!(:security_review).response
    <<~PROMPT
      Summarize this security review in 2-3 sentences that
      a non-technical manager would understand:

      #{review}
    PROMPT
  end

  # Step 4: Ruby formats the final output
  ruby(:display) do
    puts "\n" + "=" * 60
    puts "EXECUTIVE SUMMARY"
    puts "-" * 60
    puts chat!(:simple_summary).response
    puts "=" * 60 + "\n"
    puts "SECURITY REVIEW"
    puts "=" * 60
    puts agent!(:security_review).response
    puts "\n" + "-" * 60
  end
end
```

Data flows: **shell command → agent analysis → chat summary → ruby formatting**

## Resuming Conversations

Both `chat` and `agent` cogs can resume previous conversations by passing their session to a subsequent cog. This allows
multi-turn conversations where the LLM remembers context from earlier exchanges:

```ruby
execute do
  # First turn - tell the LLM something
  chat(:introduce_topic) do
    "The secret code word is 'thunderbolt'. Remember it."
  end

  # Second turn - resume the session and ask about it
  chat(:recall_code) do |my|
    my.session = chat!(:introduce_topic).session
    my.prompt = "What was the secret code word?"
  end
end
```

The same pattern works with `agent` cogs:

```ruby
execute do
  agent(:analyze) { "List files in this directory" }

  agent(:followup) do |my|
    my.session = agent!(:analyze).session
    my.prompt = "Tell me more about one of those files"
  end
end
```

**Important:** You cannot resume an agent's session in a chat cog, or vice versa. They are not interchangeable.

## Running the Workflows

To run the examples in this chapter:

```bash
# Simple chaining example
bin/roast execute --executor=dsl dsl/tutorial/02_chaining_cogs/simple_chain.rb
```

```bash
# Realistic code review workflow
bin/roast execute --executor=dsl dsl/tutorial/02_chaining_cogs/code_review.rb
```

```bash
# Session resumption with multi-turn conversations
bin/roast execute --executor=dsl dsl/tutorial/02_chaining_cogs/session_resumption.rb
```

## Try It Yourself

1. **Run both workflows** and observe how data flows between steps
2. **Modify the prompts** - Change what the agent looks for or how the chat summarizes
3. **Add a new step** - Try adding another chat step that processes the summary differently
4. **Change the order** - What happens if you try to access a cog before it runs?
5. **Try the `!` suffix** - Replace `chat(:analyze)` with `chat!(:analyze)` and see the difference

## Key Takeaways

- Name cogs with descriptive symbols: `chat(:analyze)`
- Access outputs by referencing the cog: `chat(:analyze).response`
- Use `?` to check if a cog ran: `chat?(:analyze)`
- Use `!` for convenient shorthand that raises an error right away if the cog didn't run
- Different cogs have different output methods: `.response`, `.value`, `.out`
- Many cogs have common convenience methods: `.text`, `.lines`, `.json!`
- Use `agent` for filesystem access, `chat` for pure reasoning
- Use `ruby` for custom logic and formatting
- Data flows through your workflow in the order you define steps
- Reference any past steps' output in a current step's input
- Resume conversations by passing `.session` to subsequent cogs with `my.session = ...`
- Cannot mix chat and agent sessions - they are different types

## What's Next?

In the next chapter, you'll learn how to make workflows more flexible by accepting targets and custom parameters
from the command line, so you can reuse the same workflow with different inputs.

But first, make sure you understand how outputs flow between cogs. This is the foundation of all workflows!
