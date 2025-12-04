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
bin/roast execute --executor=dsl dsl/tutorial/CHAPTER_NAME/workflow_name.rb
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

**Files:**

- `02_chaining_cogs/simple_chain.rb` - Basic chaining with `chat` cogs
- `02_chaining_cogs/code_review.rb` - Realistic workflow with `agent`, `chat`, and `ruby`

---

### Chapter 3: Configuration Options

Learn how to configure cogs to control their behavior, use different models for different steps, and manage what
gets displayed during execution.

**You'll learn:**

- Global vs per-step configuration
- Pattern-based configuration with regex
- Display options (`show_prompt!`, `no_show_response!`)
- Using different models for different steps

**Files:**

- `03_configuration_options/simple_config.rb` - Basic configuration and overrides
- `03_configuration_options/control_display_and_temperature.rb` - Configuring multiple parameters for multiple steps

---

### Chapter 4: Control Flow

Learn how to create dynamic workflows that adapt based on conditions: skipping steps, handling failures, and checking
whether steps actually ran.

**You'll learn:**

- Conditional execution with `skip!`
- Early termination with `fail!`
- Checking if cogs ran with `?` accessor
- The difference between `!`, `?`, and non-bang accessors

**Files:**

- `04_control_flow/conditional_execution.rb` - Using `skip!` and `?` accessor
- `04_control_flow/handling_failures.rb` - Command failures with `no_abort_on_failure!`, `no_fail_on_error!`, and
  explicit `fail!`

---

### Chapter 5: Reusable Scopes

Learn how to create reusable `execute` scopes that can be called multiple times with different inputs, making your
workflows more modular and maintainable.

**You'll learn:**

- Defining named execute scopes
- Calling scopes with the `call` cog
- Passing values to scopes
- Returning values with `outputs`
- Extracting outputs with `from()`

**Files:**

- `05_reusable_scopes/basic_scope.rb` - Defining and calling named scopes
- `05_reusable_scopes/parameterized_scope.rb` - Passing values to scopes
- `05_reusable_scopes/accessing_scope_outputs.rb` - Using `from()` with a block to access specific cog outputs

---

### Chapter 6: Processing Collections

Learn how to process arrays and collections by applying a named execute scope to each item with the `map` cog.

**You'll learn:**

- Using the `map` cog to process collections
- Collecting and reducing results with `collect` and `reduce`
- Parallel execution with `parallel` configuration
- Accessing specific iteration outputs
- Working with iteration indices

**Files:**

- `06_processing_collections/basic_map.rb` - Basic map usage with collect, reduce, and accessing specific iterations
- `06_processing_collections/parallel_map.rb` - Serial, limited parallel, and unlimited parallel execution

---

### Coming Soon

Future chapters will cover:

- Iterative workflows with `repeat`
- Running cogs asynchronously with `async!`

---

Let's get started with
[Chapter 1](https://github.com/Shopify/roast/blob/edge/dsl/tutorial/01_your_first_workflow/README.md)!
