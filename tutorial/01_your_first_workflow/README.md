# Chapter 1: Your First Workflow

In this chapter, you'll create and run your first Roast workflow. We'll start with the absolute simplest example, then
show you how to add basic configuration.

## What You'll Learn

- The basic structure of a Roast workflow file
- How to use the `chat` cog to interact with an LLM
- How to run workflows from the command line
- How to configure model settings

## Understanding Workflows

Before we dive into code, let's understand what a Roast workflow is:

**A workflow is a sequence of steps that accomplish a task.** Think of it like a recipe: you define each step in order,
specify what inputs each step needs, and describe how they connect together.

### Key Concepts

- **Steps** - Individual units of work (like "analyze this code" or "summarize this text")
- **Cogs** - The building blocks that implement step types (Roast comes with a comprehensive set of basic cogs for
  interacting with LLMs, invoking coding agents, running shell commands, processing data, as wells as complex flow
  control)
- **Declarative style** - You describe *what* you want done, the inputs each step needs, and how they connect together.
  Roast takes care of the rest

For example, instead of writing code to open files, parse them, call APIs, handle errors, etc., you write:

```ruby
execute do
  chat { "Analyze this code and suggest improvements: #{my_code}" }
end
```

Roast handles the details. You focus on the workflow.

In this chapter, we'll start with the simplest workflow: a single step using the `chat` cog. In later chapters, you'll
learn how to invoke coding agents, run shell commands, and chain multiple steps together to build sophisticated
workflows.

## The Basics

Every Roast workflow is a Ruby file that defines what work to do. The simplest workflow has just one part:

1. **Execute block** - Contains the work to perform

### Minimal Syntax

```ruby
execute do
  # Your workflow goes here
end
```

That's it! Everything happens inside the `execute do ... end` block.

## Your First Chat Cog

The `chat` cog sends a prompt to a cloud-based LLM and gets a response back. Here's a simplest example:

```ruby
execute do
  chat { "Say hello!" }
end
```

When you run this, Roast will:

1. Send the prompt "Say hello!" to default LLM provider and model (OpenAI gpt-4o-mini)
2. Wait for the response
3. Display the response in your terminal, along with LLM usage statistics

### Longer Prompts

For real workflows, you'll want more detailed prompts. Use Ruby's heredoc syntax for multi-line prompts:

```ruby
execute do
  chat do
    <<~PROMPT
      You are a helpful AI assistant.

      Please introduce yourself and explain what Roast is in 2-3 sentences.
      Keep your response friendly and concise.
    PROMPT
  end
end
```

Or define your prompts in a template file using ERB syntax and include them in your workflow

```ruby
execute do
  chat { template("path_to_prompt_file.md.erb", { context: }) }
end
```

## Adding Configuration

You can configure which model to use, which provider, and other settings. Configuration goes in a `config do ... end`
block:

```ruby
config do
  chat do
    model "gpt-4o-mini" # Use OpenAI's fast model
    provider :openai # Use OpenAI (can also be :anthropic)
    show_prompt! # Display the prompt before sending
  end
end

execute do
  chat do
    <<~PROMPT
      Explain what an AI workflow is in simple terms.
    PROMPT
  end
end
```

### Configuration Options

Common options you can set:

- `model "name"` - Which LLM model to use
    - OpenAI: "gpt-4o", "gpt-4o-mini", "gpt-4-turbo"
    - Anthropic: "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"
- `provider :name` - Which LLM provider
    - `:openai` or `:anthropic`
- `show_prompt!` - Display the prompt being sent
- `show_response!` - Display the response (on by default)
- `show_stats!` - Display token usage statistics (on by default)
- `no_display!` - Turn off all output (useful when you just want to pass the output to a subsequent cog)

## Running the Workflows

To run any workflow in this chapter:

```bash
# From the project root
bin/roast execute --executor=dsl dsl/tutorial/01_your_first_workflow/hello.rb
```

Or the configured version:

```bash
bin/roast execute --executor=dsl dsl/tutorial/01_your_first_workflow/configured_chat.rb
```

You should see:

1. The prompt being sent (if you enabled `show_prompt!`)
2. The LLM's response
3. Statistics about token usage

## Try It Yourself

1. **Run both example workflows** in this chapter
2. **Modify the prompts** - Ask different questions
3. **Try different models** - Change "gpt-4o-mini" to "gpt-4o" in the config
4. **Experiment with display settings** - Try `no_show_stats!` and see what happens

## Key Takeaways

- The `execute do ... end` block contains your workflow logic
- The `chat` cog sends prompts to cloud-based LLMs
- Use `<<~PROMPT ... PROMPT` for multi-line prompts
- The `config do ... end` block (before execute) sets up cog behavior
- Run workflows with `bin/roast execute --executor=dsl path/to/workflow.rb`

## What's Next?

In the next chapter, you'll learn how to chain multiple cogs together, so the output of one becomes the input to
another. This is where Roast becomes powerful!

But first, make sure you can successfully run both workflows in this chapter. Experiment with different prompts and
configurations until you're comfortable.
