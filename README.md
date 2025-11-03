# Roast

Roast is a Ruby DSL for building powerful agentic workflows that seamlessly combine deterministic code with AI capabilities. It enables you to create feedback loops where AI agents and traditional tools work together, allowing you to build sophisticated automation that learns, adapts, and iterates on solutions.

Whether you're generating code, analyzing data, or orchestrating complex multi-step processes, Roast makes it easy to leverage the strengths of both AI and traditional programming in a single unified workflow.

## Installation

Add Roast to your `Gemfile`:

```ruby
gem 'roast'
```

Then run:

```bash
bundle install
```

Verify the installation:

```bash
bin/roast version
```

## Quick Start

Create your first workflow by making a new file `my_workflow.rb`:

```ruby
# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  agent { "Explain what a feedback loop is in one sentence" }
end
```

Run it:

```bash
bin/roast execute my_workflow.rb
```

This simple example uses an AI agent ([`simple_agent.rb`](https://github.com/Shopify/roast/dsl/simple_agent.rb)), but Roast workflows can also include:
- **Ruby code** ([`ruby_cog.rb`](https://github.com/Shopify/roast/dsl/ruby_cog.rb)) for deterministic logic
- **Command execution** ([`ruby_cog.rb`](https://github.com/Shopify/roast/dsl/ruby_cog.rb)) to run shell commands
- **Chat sessions** ([`simple_chat.rb`](https://github.com/Shopify/roast/dsl/simple_chat.rb)) that maintain conversation context
- **Parallel execution** ([`parallel_map.rb`](https://github.com/Shopify/roast/dsl/parallel_map.rb)) for concurrent tasks
- **Map/reduce patterns** ([`map_reduce.rb`](https://github.com/Shopify/roast/dsl/map_reduce.rb)) for processing collections

## Core Concepts

### Cogs: The Building Blocks

Cogs are the individual steps in your workflow. A cog instance is represented as `cog_type(:name)`, for example `cmd(:hello)` or `agent(:summarizer)`. Each cog:
- Has a type (`cmd`, `agent`, `chat`, `ruby`, `map`, etc.)
- Can optionally have a name for reference (e.g., `:hello`), or be anonymous
- Takes an input block that returns configuration or data
- Produces an output that other cogs can use

**Important:** Named cogs can only be executed once per workflow, but their outputs can be referenced any number of times. You cannot call the same named cog with different inputs multiple times.

### Input Blocks

Input blocks define the input to a cog's internal logic. The cog itself is a black box that performs its specific operation (running a command, calling an AI, executing Ruby code, etc.). Input blocks can be simple or complex:

```ruby
# Simple: return a string directly (anonymous cog)
cmd { "ls -la" }

# Named: for reference by other cogs
cmd(:simple) { "ls -la" }

# Complex: configure using the input object
cmd(:complex) do |my|
  my.command = "echo"
  my.args = ["Hello", "World"]
end

# Access other cog outputs
cmd(:dependent) do |my|
  previous_output = cmd!(:simple).out  # ! means "wait for and get output"
  my.command = "echo"
  my.args = [previous_output]
end
```

The input block receives:
1. `my` - the input configuration object
2. `executor_scope_value` - values passed from map/reduce operations
3. `executor_scope_index` - index when iterating over collections

### Workflow Structure

Roast workflows have two main sections:

**`config` block** - Define default behavior and settings for cogs (workflow steps):

```ruby
config do
  agent do
    provider :claude
    model "haiku"
  end
  cmd { display! }  # Show command output by default
end
```

**`execute` block** - Define the actual workflow steps:

```ruby
execute do
  cmd(:hello) { "echo 'Hello World'" }
  agent { "Summarize this: #{cmd!(:hello).out}" }
end
```

## Available Cogs

### `cmd` - Execute Shell Commands

Runs shell commands and captures their output.

**Input:**
```ruby
cmd(:name) { "echo hello" }  # Simple: command string

cmd(:name) do |my|            # Complex: configure command and args
  my.command = "git"
  my.args = ["log", "--oneline", "-10"]
end
```

**Output:**
- `.out` - stdout as a string
- `.err` - stderr as a string
- `.status` - Process::Status object

**Config options:**
- `display!` / `print_all!` - Print stdout and stderr
- `print_stdout!` / `no_print_stdout!` - Control stdout printing
- `print_stderr!` / `no_print_stderr!` - Control stderr printing
- `raw_output!` / `clean_output!` - Keep/strip whitespace (default: clean)

### `ruby` - Execute Ruby Code

Execute arbitrary Ruby code within the workflow, useful for data transformation and logic.

**Input:**
```ruby
ruby(:name) do
  # Any Ruby code
  result = some_calculation()
  process_data(result)
  # Return value becomes the output
  result
end
```

**Output:**
- `.value` - the return value from the block

### `agent` - AI Agent

Call an AI agent to perform tasks with tool access and extended capabilities.

**Input:**
```ruby
agent(:name) { "Your prompt here" }

agent(:name) do |my|
  my.prompt = "Your prompt here"
end
```

**Output:**
- `.response` - the agent's text response

**Config options:**
- `provider(:claude)` - Set the AI provider (default: `:claude`)
- `model("haiku")` - Set the model name
- `initial_prompt("...")` - Add a system prompt component
- `show_prompt!` / `no_show_prompt!` - Display the prompt
- `show_progress!` / `no_show_progress!` - Display thinking/intermediate output (default: on)
- `show_response!` / `no_show_response!` - Display the final response (default: on)
- `display!` / `no_display!` / `quiet!` - Control all output
- `apply_permissions!` - Apply system permissions when running

### `chat` - Chat with LLM

Call an LLM for text generation and responses.

**Input:**
```ruby
chat(:name) { "What is the deepest lake?" }
```

**Output:**
- `.response` - the LLM's text response

**Config options:**
- `model("gpt-4o-mini")` - Set the model (default: `gpt-4o-mini`)
- `api_key(ENV["OPENAI_API_KEY"])` - Set API key
- `base_url("...")` - Set API base URL
- `provider(:openai)` - Set provider (default: `:openai`)
- `assume_model_exists(true/false)` - Skip model validation

### `call` - Call Execution Scope

Execute a named execution scope (subroutine) within your workflow.

**Input:**
```ruby
# Define a scope
execute(:my_subroutine) do
  cmd { "echo 'In subroutine'" }
end

# Call it
execute do
  call(:name, run: :my_subroutine) { optional_input_value }
end
```

**Output:**
- Access the called scope's execution context via `from(call!(:name)) { ... }`

### `map` - Iterate Over Items

Process a collection of items by running an execution scope for each item.

**Input:**
```ruby
map(:name, run: :process_item) do |my|
  my.items = [1, 2, 3, 4, 5]
  my.initial_index = 0  # Optional starting index
end

map(:name, run: :process_item) { [1, 2, 3] }  # Simple form
```

**Output:**
- Use `collect(map!(:name)) { ... }` to gather results
- Use `reduce(map!(:name), initial) { |acc| ... }` to reduce results

**Config options:**
- `parallel(n)` - Process up to `n` items in parallel (default: 1, sequential)
- `parallel!` / `parallel(0)` - Process all items in parallel
- `no_parallel!` - Force sequential processing

