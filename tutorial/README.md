![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Roast Tutorial

🔥 _version 1.0 feature preview_ 🔥

Welcome to the Roast tutorial! This guide will teach you how to build AI workflows using the Roast DSL.

## What is Roast?

Roast is a Ruby-based domain-specific language for creating structured AI workflows
and building complex AI-powered automation. You write workflows in a simple Ruby syntax to orchestrate LLM calls,
run coding agents, process data, and so much more.

## Prerequisites

- Ruby installed (3.4.2+)
- Roast gem installed
- API keys for your AI providers of choice (to use LLM chat)
- Claude Code CLI installed and configured (to use coding agents)

## How to Use This Tutorial

Each chapter is a self-contained lesson with:

- **README.md** - Lesson content with explanations and code snippets
- **Workflow files** (`.rb`) - Complete, runnable examples
- **data/** folder - Sample data files (when needed)

To run any example:

```bash
bin/roast execute tutorial/CHAPTER_NAME/workflow_name.rb
```

## Tutorial Chapters

### Chapter 1: Your First Workflow

Quickly learn the basics: how to create and run a simple workflow with a single chat cog.

**You'll learn:**

- Basic workflow file structure
- Using the `chat` cog
- Running workflows
- Simple configuration

**Files:**

- `01_your_first_workflow/hello.rb` - Simplest possible workflow
- `01_your_first_workflow/configured_chat.rb` - Adding configuration

---

### Chapter 2: Chaining Cogs Together

Learn how to build multi-step workflows by chaining cogs together, where the output of one step becomes the input to the
next.

**You'll learn:**

- How to name cogs and reference their outputs
- Using the `!` suffix to access previous results
- The difference between `agent` and `chat` cogs
- Using the `ruby` cog for custom logic
- How data flows through a workflow
- Resuming conversations with session management

**Files:**

- `02_chaining_cogs/simple_chain.rb` - Basic chaining with `chat` cogs
- `02_chaining_cogs/code_review.rb` - Realistic workflow with `agent`, `chat`, and `ruby`
- `02_chaining_cogs/session_resumption.rb` - Multi-turn conversations with session resumption

---

### Chapter 3: Targets and Parameters

Learn how to make workflows flexible by accepting targets and custom parameters from the command line.

**You'll learn:**

- Using `target!` for single-target workflows (file, url, etc.)
- Using `targets` for a workflow that can accept multiple targets in one shot 
- Passing custom arguments with `args` and `kwargs`
- Checking for argument presence
- Combining targets with arguments

**Files:**

- `03_targets_and_params/single_target.rb` - Processing a single URL with `target!`
- `03_targets_and_params/multiple_targets.rb` - Processing multiple files with arguments

---

### Chapter 4: Configuration Options

Learn how to configure cogs to control their behavior, use different models for different steps, and manage what
gets displayed during execution.

**You'll learn:**

- Global vs per-step configuration
- Pattern-based configuration with regex
- Display options (`show_prompt!`, `no_show_response!`)
- Using different models for different steps

**Files:**

- `04_configuration_options/simple_config.rb` - Basic configuration and overrides
- `04_configuration_options/control_display_and_temperature.rb` - Configuring multiple parameters for multiple steps

---

### Chapter 5: Control Flow

Learn how to create dynamic workflows that adapt based on conditions: skipping steps, handling failures, and checking
whether steps actually ran.

**You'll learn:**

- Conditional execution with `skip!`
- Early termination with `fail!`
- Checking if cogs ran with `?` accessor
- The difference between `!`, `?`, and non-bang accessors

**Files:**

- `05_control_flow/conditional_execution.rb` - Using `skip!` and `?` accessor
- `05_control_flow/handling_failures.rb` - Command failures with `no_abort_on_failure!`, `no_fail_on_error!`, and
  explicit `fail!`

---

### Chapter 6: Reusable Scopes

Learn how to create reusable `execute` scopes that can be called multiple times with different inputs, making your
workflows more modular and maintainable.

**You'll learn:**

- Defining named execute scopes
- Calling scopes with the `call` cog
- Passing values to scopes
- Returning values with `outputs`
- Extracting outputs with `from()`

**Files:**

- `06_reusable_scopes/basic_scope.rb` - Defining and calling named scopes
- `06_reusable_scopes/parameterized_scope.rb` - Passing values to scopes
- `06_reusable_scopes/accessing_scope_outputs.rb` - Using `from()` with a block to access specific cog outputs

---

### Chapter 7: Processing Collections

Learn how to process arrays and collections by applying a named execute scope to each item with the `map` cog.

**You'll learn:**

- Using the `map` cog to process collections
- Collecting and reducing results with `collect` and `reduce`
- Parallel execution with `parallel` configuration
- Accessing specific iteration outputs
- Working with iteration indices

**Files:**

- `07_processing_collections/basic_map.rb` - Basic map usage with collect, reduce, and accessing specific iterations
- `07_processing_collections/parallel_map.rb` - Serial, limited parallel, and unlimited parallel execution

---

### Chapter 8: Iterative Workflows

Learn how to create iterative workflows with the `repeat` cog, which executes a scope repeatedly until a condition is
met, with each iteration's output becoming the next iteration's input.

**You'll learn:**

- Using the `repeat` cog for iterative transformations
- How output from one iteration becomes input to the next
- Breaking out of loops with `break!`
- Skipping to the next iteration with `next!`
- Accessing specific iterations and the final result with `from`
- Processing all iterations with `collect` and `reduce`
- Using the `outputs` block for controlling iteration values

**Files:**

- `08_iterative_workflows/basic_repeat.rb` - Iterative text refinement showing basic repeat patterns
- `08_iterative_workflows/conditional_break.rb` - Number guessing game with conditional termination
- `08_iterative_workflows/skip_with_next.rb` - Processing numbers while skipping even values

---

### Chapter 9: Asynchronous Cogs

Learn how to run cogs asynchronously to improve workflow performance when you have independent tasks
that can run concurrently.

**You'll learn:**

- How async cogs differ from parallel map execution
- Configuring cogs to run asynchronously with `async!`
- How async execution works and when cogs block
- Using synchronous cogs as synchronization barriers
- Real-world patterns for parallel code analysis
- When to use async cogs vs other parallelization methods

**Files:**

- `09_async_cogs/basic_async.rb` - Simple async execution with multiple independent agent tasks
- `09_async_cogs/parallel_analysis.rb` - Parallel code analysis using multiple agents
- `09_async_cogs/sync_barriers.rb` - Using synchronous cogs to control execution phases

---

### Chapter 10: Custom Cogs

Learn how to create custom cogs to extend Roast with domain-specific operations and integrations.

**You'll learn:**

- When to create custom cogs vs using built-in cogs
- Anatomy of a cog (Config, Input, Output, execute)
- Creating simple and complex custom cogs
- Loading cogs from gems vs local files
- Cog naming conventions and file structure
- Packaging custom cogs as reusable gems

**Examples referenced:**

- `examples/demo/simple_external_cog.rb` - Using custom cogs from gems and local files
- `examples/plugin-gem-example/lib/simple.rb` - Simple custom cog
- `examples/plugin-gem-example/lib/other.rb` - Namespaced custom cog
- `examples/demo/cogs/local.rb` - Project-specific local cog
- `examples/plugin-gem-example/` - Complete gem structure

---

### Chapter 11: Custom Agent Providers

Learn how to create custom agent providers to integrate alternative agent backends with the `agent` cog.

**You'll learn:**

- How the agent provider system works
- When to create custom providers
- Anatomy of a provider (Output class, invoke method)
- Creating providers for different agent backends
- Mock providers for testing workflows
- Loading providers from gems vs local files
- Packaging custom providers as reusable gems

**Examples referenced:**

- `examples/demo/simple_external_agent.rb` - Using a custom agent provider
- `examples/plugin-gem-example/lib/cool_agent.rb` - Simple custom provider
- `examples/plugin-gem-example/` - Complete gem structure

---

Let's get started with
[Chapter 1](https://github.com/Shopify/roast/blob/edge/tutorial/01_your_first_workflow/README.md)!
