# Document 2: DSL Users Guide

_How to write Roast workflows. The practical "using the tool" guide._

> **Prerequisites**: Read [01-architecture-overview.md](./01-architecture-overview.md) first.
> **Reference companion**: [03-cog-reference.md](./03-cog-reference.md) for per-cog config options, input fields, output fields, and defaults.

---

## Table of Contents

1. [Your First Workflow](#1-your-first-workflow)
2. [Cog Basics](#2-cog-basics)
3. [Configuring Cogs](#3-configuring-cogs)
4. [Chaining Cogs and Accessing Outputs](#4-chaining-cogs-and-accessing-outputs)
5. [Targets and Parameters](#5-targets-and-parameters)
6. [Control Flow](#6-control-flow)
7. [Reusable Scopes (call)](#7-reusable-scopes-call)
8. [Processing Collections (map)](#8-processing-collections-map)
9. [Iterative Workflows (repeat)](#9-iterative-workflows-repeat)
10. [Async Execution](#10-async-execution)
11. [Templates and Prompts](#11-templates-and-prompts)
12. [Session Management](#12-session-management)
13. [Common Idioms Quick-Reference](#13-common-idioms-quick-reference)

---

## 1. Your First Workflow

A Roast workflow is a Ruby file that defines two things: **configuration** (what cogs look like) and **execution** (what cogs exist and in what order). Every workflow has this basic structure:

```ruby
#: self as Roast::Workflow
config do
  # configure cog types here
end

execute do
  # declare and run cogs here
end
```

The `#: self as Roast::Workflow` annotation on line 1 is optional but recommended. It tells Sorbet (and your editor) that the top-level `self` in this file is a `Roast::Workflow` instance, enabling autocomplete for `config`, `execute`, and `use`.

**Running a workflow:**

```bash
devx roast my_workflow.rb            # via devx
bundle exec roast my_workflow.rb     # via bundler
```

**What happens when you run this:**

1. `Workflow.from_file` reads the file as a raw string
2. `instance_eval` evaluates it on the Workflow instance — this collects the `config {}` and `execute {}` blocks as procs, but does **not** evaluate their contents yet
3. `prepare!` evaluates the config procs (binding cog configuration) and the execute procs (declaring cogs and building the execution stack)
4. `start!` runs the cogs in declaration order

> **Source**: `Workflow.from_file` at `lib/roast/workflow.rb:18–30`, `extract_dsl_procs!` at line 134–136.

**Key principle**: The `config {}` block runs at **prepare time**. The `execute {}` block also runs at prepare time (to declare cogs), but the individual cog input blocks within it run at **execution time**. This is the declarative two-phase lifecycle described in Document 1.

---

## 2. Cog Basics

### Declaring Cogs

Cogs are declared inside the `execute` block. The method name is the cog type, the first argument is the cog's name (as a Symbol), and the block is the **input block**:

```ruby
execute do
  cmd(:list_files) { "ls -la" }

  chat(:analyze) do |my|
    my.prompt = "Analyze these files: #{cmd!(:list_files).text}"
  end

  agent(:review) do |my|
    my.prompts = ["Review the analysis: #{chat!(:analyze).response}"]
  end

  ruby(:summarize) do |my|
    my.value = { analysis: chat!(:analyze).text, review: agent!(:review).text }
  end
end
```

The four standard cog types are `cmd`, `chat`, `agent`, and `ruby`. The three system cog types (`call`, `map`, `repeat`) are covered in Sections 7–9.

### The Input Block

> **⚠️ Key Concept: The Input Block Is More Than a Setter**
>
> The input block is **arbitrary Ruby code** that runs before the cog does its
> own work. Its primary purpose is to populate an empty Input instance so the
> cog knows what to do, but you can (and often should) do other preparation
> work here: set up files, load data, compute intermediate values, transform
> outputs from prior cogs, etc. Think of it as "everything that needs to happen
> before this cog fires."
>
> For `cmd`, `chat`, and `agent` cogs, the cog's own execution (running a shell
> command, calling the LLM, invoking the agent) is a **separate step** that
> happens after your input block returns and the framework validates the input.
>
> The `ruby` cog is the **deliberate exception**: its `execute` method is a
> no-op that just passes through the `value` attribute. All real work happens
> inside the input block itself. See [Section 5 in the Cog Reference](./03-cog-reference.md#5-ruby-cog)
> for details on why this exists and how to use it.

The input block receives up to three arguments:

```ruby
chat(:name) do |my, scope_value, scope_index|
  # my          → the cog's Input object (e.g., Chat::Input) — starts EMPTY; your job is to fill it
  # scope_value → the current scope's value (WorkflowParams at top-level, or item in a map/repeat)
  # scope_index → the current scope's index (0 at top-level, iteration index in map/repeat)
end
```

The input block runs at **execution time**, inside `Cog.run!` (line 79 of `lib/roast/cog.rb`). It is evaluated via `instance_exec` on the `CogInputContext`, meaning you have access to all output accessors, workflow context methods, and control flow primitives within it.

> **Source**: `input_context.instance_exec(input_instance, executor_scope_value, executor_scope_index, &@cog_input_proc)` at `lib/roast/cog.rb:79–81`.

### Return Value Coercion

You can set input fields in two ways:

**Explicit** (via the `my` object):
```ruby
cmd(:greet) do |my|
  my.command = "echo"
  my.args = ["Hello", "World"]
end
```

**Implicit** (via block return value):
```ruby
cmd(:greet) { "echo Hello World" }
```

When the block returns a value, the framework attempts to **coerce** it into a valid input. The coercion rules vary by cog type:

| Cog Type | Return Value | Coercion |
|----------|-------------|----------|
| `cmd` | `String` | Sets `command` |
| `cmd` | `Array` | First element → `command`, rest → `args` (safe from shell injection) |
| `chat` | `String` | Sets `prompt` |
| `agent` | `String` | Wraps in array → `prompts = [string]` |
| `agent` | `Array[String]` | Sets `prompts` (multi-prompt sequential invocation) |
| `ruby` | Any value | Sets `value` |
| `call` | Any value | Sets `value` |
| `map` | Enumerable | Converts to array → sets `items` |
| `repeat` | Any value | Sets `value` |

The coercion mechanism is a two-phase validation process inside `coerce_and_validate_input!` (`lib/roast/cog.rb:149–157`):

1. `validate!` — check if the input is already valid (maybe the block set fields explicitly)
2. If `InvalidInputError` → `coerce(return_value)` — try to interpret the return value
3. `validate!` again — if still invalid, the cog fails

This means explicit setting always takes priority over return value coercion: if you set `my.command = "..."` and also return a string, the explicit value wins because `validate!` passes on the first attempt and coercion is never invoked.

> **Source**: `Cog::Input` base class at `lib/roast/cog/input.rb`, per-cog coerce implementations in each cog's `Input` subclass.

### Anonymous Cogs

If you omit the name, the cog gets a random UUID name and is marked anonymous:

```ruby
execute do
  cmd { "echo hello" }  # anonymous — exists in the store but can't be referenced by name
end
```

Anonymous cogs execute normally but their output cannot be accessed by other cogs (there's no stable name to reference). Use named cogs whenever you need to chain outputs.

> **Source**: `Cog.generate_fallback_name` at `lib/roast/cog.rb:23` uses `Random.uuid.to_sym`.

---

## 3. Configuring Cogs

Configuration happens inside the `config {}` block. There are four levels of configuration specificity, applied in a merge cascade where more-specific values override less-specific ones.

### Global Config

Applies to **all** cogs of **all** types:

```ruby
config do
  global do
    working_directory "/tmp"
    abort_on_failure!
  end
end
```

Global config seeds every cog's configuration. It uses `Cog::Config` (the base class), so only base-level options are available: `async!`/`no_async!`, `abort_on_failure!`/`no_abort_on_failure!`, `working_directory`, and hash-style `[]=` for arbitrary keys.

> **Source**: `ConfigManager#bind_global` at `lib/roast/config_manager.rb:124–132`. Global values are extracted via `instance_variable_get(:@values)` in `config_for` (line 48) — the only place in the codebase that reaches into `@values` from outside the Config class.

### Type-General Config

Applies to **all** cogs of a **specific type**:

```ruby
config do
  chat do
    model "gpt-4o"
    temperature 0.0
  end

  agent do
    async!
  end
end
```

When you call `chat` (or any cog type method) with **no arguments**, the block configures the type-general config for that cog type.

### Regex Config

Applies to all cogs whose **name matches** a pattern:

```ruby
config do
  agent(/review_/) do
    model "claude-sonnet-4-20250514"
    async!
  end

  chat(/analyze_/) do
    temperature 0.0
  end
end
```

When you pass a `Regexp` as the first argument, the block configures a regex-scoped config. Multiple regex patterns can match the same cog — they are all merged in the order they appear.

### Per-Cog Config

Applies to a **single named cog**:

```ruby
config do
  chat(:summarize) do
    model "gpt-4o-mini"
    temperature 0.7
  end
end
```

When you pass a `Symbol` as the first argument, the block configures the name-scoped config for that specific cog.

### The Merge Cascade

When a cog runs, its final configuration is computed by merging all applicable configs in order:

```
1. Global config values (seed)
2. Type-general config (merge)
3. All matching regex configs (merge, in declaration order)
4. Name-specific config (merge)
5. validate! (whole-config validation)
```

At each step, `Hash#merge` is used — right-side values (more specific) win. The result is deep-dup'd before being passed to the cog, so no cog can mutate another's configuration.

> **Source**: `ConfigManager#config_for` at `lib/roast/config_manager.rb:44–59`.

### Reopenable Config Blocks

You can have **multiple** `config {}` blocks in a workflow. They are collected as procs and evaluated sequentially during `prepare!`. This means later config blocks can override earlier ones:

```ruby
config do
  chat { model "gpt-4o-mini" }
end

config do
  chat(:important) { model "gpt-4o" }
end
```

Both blocks target the same underlying config objects — they accumulate.

---

## 4. Chaining Cogs and Accessing Outputs

### Naming Cogs

Always name cogs you want to reference later:

```ruby
execute do
  cmd(:list) { "ls" }
  chat(:analyze) { "Analyze: #{cmd!(:list).text}" }
end
```

The name is a `Symbol` passed as the first argument. Within the same execution scope, names must be unique — duplicate names raise `CogAlreadyDefinedError`.

### The Three Accessor Variants

Every registered cog type gets three accessor methods on the `CogInputContext`, usable inside any cog's input block:

| Method | Behavior | Returns |
|--------|----------|---------|
| `cmd(:name)` | Tolerant — returns `nil` if the cog was skipped, failed, stopped, or hasn't run yet | `Cog::Output?` |
| `cmd!(:name)` | Strict — blocks on async cogs, raises on any error state | `Cog::Output` |
| `cmd?(:name)` | Boolean — `true` if the cog produced output | `bool` |

**Critical**: All three methods **always** raise `CogDoesNotExistError` if the named cog doesn't exist in the current scope. The tolerant variant only suppresses state-related errors (skipped, failed, stopped, not-yet-run), never existence errors. This is intentional — a nonexistent cog name is likely a typo.

**Blocking behavior**: `cmd!(:name)` calls `cog.wait` before checking state, which blocks the current fiber if the referenced cog is async and still running. This is how sync cogs naturally wait for async dependencies.

> **Source**: `CogInputManager#cog_output!` at `lib/roast/cog_input_manager.rb:69–79`, `cog_output` at lines 54–61.

### Output Deep Copy

Every output access returns a **deep copy** (`cog.output.deep_dup`). This prevents downstream cogs from mutating shared output objects — critical for correctness in concurrent execution.

### Convenience Methods on Outputs

Each cog type's Output class includes mixin modules that provide convenience methods for common extraction patterns. The key methods:

**Text extraction** (from `WithText`):
- `.text` — stripped string
- `.lines` — array of stripped lines

**JSON extraction** (from `WithJson`):
- `.json` — parsed JSON (nil on error), keys symbolized
- `.json!` — parsed JSON (raises on error)

**Number extraction** (from `WithNumber`):
- `.integer` / `.integer!` — extracted integer
- `.float` / `.float!` — extracted float

**Per-cog output fields:**

| Cog Type | Primary Output | Raw Text Source |
|----------|---------------|-----------------|
| `cmd` | `.out`, `.err`, `.status` | `out` |
| `chat` | `.response`, `.session` | `response` |
| `agent` | `.response`, `.session`, `.stats` | `response` |
| `ruby` | `.value` | N/A (no mixins) |

> **See**: [03-cog-reference.md](./03-cog-reference.md) for exhaustive per-cog output field documentation.

### Chaining Examples

```ruby
execute do
  cmd(:ls) { "ls -la" }

  # Access text output
  chat(:analyze) { "Files:\n#{cmd!(:ls).text}" }

  # Parse JSON from output
  cmd(:json) { "echo '{\"count\": 42}'" }
  ruby(:result) { cmd!(:json).json![:count] }

  # Chain LLM outputs
  chat(:draft) { "Write a summary" }
  chat(:refine) { "Improve this: #{chat!(:draft).response}" }

  # Extract numbers from LLM responses
  chat(:estimate) { "How many files?" }
  ruby(:count) { chat!(:estimate).integer }
end
```

---

## 5. Targets and Parameters

Roast workflows receive parameters from the command line. The CLI uses a `--` separator to distinguish roast arguments from workflow arguments:

```bash
roast execute my_workflow.rb target1 target2 -- retry force name=Samantha
```

- **Before** `--`: targets (positional arguments for the workflow) and roast flags
- **After** `--`: workflow arguments parsed into `args` (simple flags) and `kwargs` (key=value pairs)

### Accessing Parameters

These methods are available in any cog input block, defined on the `CogInputContext` by `CogInputManager#bind_workflow_context` (`lib/roast/cog_input_manager.rb:82–104`):

| Method | Returns | Behavior |
|--------|---------|----------|
| `target!` | `String` | Raises `ArgumentError` unless exactly 1 target |
| `targets` | `Array[String]` | Defensive copy (`.dup`) |
| `arg?(value)` | `bool` | Checks if flag is in args |
| `args` | `Array[Symbol]` | Defensive copy |
| `kwarg(key)` | `String?` | Returns `nil` if missing |
| `kwarg!(key)` | `String` | Raises `ArgumentError` if missing |
| `kwarg?(key)` | `bool` | Checks if key exists |
| `kwargs` | `Hash[Symbol, String]` | Defensive copy |
| `tmpdir` | `Pathname` | Auto-created temp directory, cleaned on exit |

**Important**: All kwarg values are **strings**. There is no automatic type coercion from the CLI. If you need integers, parse them yourself: `kwarg!(:count).to_i`.

### The Scope Value

The top-level scope value is the `WorkflowParams` object itself. This means the second block parameter at the top level is the params object:

```ruby
execute do
  ruby(:info) do |_, params|
    params.targets  # same as calling targets
  end
end
```

In called scopes (`call`, `map`, `repeat`), the second parameter is whatever value was passed into that scope.

> **Source**: `WorkflowParams` is passed as `scope_value:` to the top-level `ExecutionManager` at `lib/roast/workflow.rb:54`.

---

## 6. Control Flow

Roast provides four control flow primitives, available in any cog input block (hardcoded on `CogInputContext` at `lib/roast/cog_input_context.rb:15–32`):

### skip!

Silently skip the current cog. The cog is marked as `skipped` and produces no output:

```ruby
cmd(:optional) do
  skip! unless arg?(:verbose)
  "ls -la"
end
```

`skip!` raises `ControlFlow::SkipCog`, which is always caught inside `Cog.run!` and never propagates. The cog simply doesn't execute.

### fail!

Mark the current cog as failed. Optionally pass a message:

```ruby
chat(:validate) do |my|
  fail! "Input too large" if targets.length > 100
  my.prompt = "Validate: #{targets.join(', ')}"
end
```

`fail!` raises `ControlFlow::FailCog`. By default, failed cogs **abort the workflow** — `abort_on_failure?` defaults to `true`. To make a cog's failure non-fatal:

```ruby
config do
  chat(:validate) { no_abort_on_failure! }
  # or equivalently:
  chat(:validate) { continue_on_failure! }
end
```

When `abort_on_failure?` is `false`, the cog is marked failed but execution continues. Accessing a failed cog's output via `chat(:validate)` (tolerant) returns `nil`; via `chat!(:validate)` (strict) raises `CogFailedError`.

> **Source**: `Cog.run!` catches `FailCog` at `lib/roast/cog.rb:87–92`, re-raises only if `config.abort_on_failure?`.

### next!

Skip to the next iteration in a `map` or `repeat` loop. In a `call` scope, terminates the scope early:

```ruby
execute(:process_item) do
  ruby(:check) do |_, item|
    next! if item.nil?  # skip nil items
    item
  end
  chat(:analyze) { "Analyze: #{ruby!(:check).value}" }
end
```

`next!` raises `ControlFlow::Next`. The cog is marked `skipped` and the exception always propagates. In a serial `map`, it advances to the next item. In a `call`, it's caught and the scope returns early.

**⚠️ Sync/Async Divergence**: `next!` behaves differently depending on whether the cog is sync or async. In a sync cog, the exception propagates out of `ExecutionManager.run!` to the parent scope (e.g., advancing a Map iteration). In an async cog, the exception is swallowed by the barrier handler — remaining cogs in the scope stop, but the parent scope is not signaled. See [07-control-flow-reference.md](./07-control-flow-reference.md) for the full propagation matrix.

### break!

Exit the current loop or scope entirely:

```ruby
execute(:iterate) do
  ruby(:check) do |_, value, index|
    break! if index >= 10
    value
  end
end
```

`break!` raises `ControlFlow::Break`. Like `next!`, the cog is marked `skipped` and the exception propagates. `break!` always propagates regardless of sync/async status. In a `repeat`, it exits the loop. In a `map`, it stops iteration. At the top-level, `Workflow.start!` catches it and terminates the workflow gracefully.

### fail_on_error! (cmd-specific)

For `cmd` cogs, a non-zero exit status is treated as a failure by default. To allow non-zero exits:

```ruby
config do
  cmd(:grep) { no_fail_on_error! }
end

execute do
  cmd(:grep) { "grep -c pattern file.txt" }
  # Even if grep exits with 1 (no matches), the cog succeeds.
  # Access exit code: cmd!(:grep).status.exitstatus
end
```

> **Source**: `Cogs::Cmd::Config` defines `fail_on_error!` / `no_fail_on_error!`. Default is `true`.

---

## 7. Reusable Scopes (call)

Named execution scopes let you group cogs into reusable units.

### Defining a Scope

Scopes are defined at the top level with `execute(:name)`:

```ruby
execute(:greet) do
  cmd(:echo) do |_, name|
    ["echo", "Hello, #{name}!"]
  end
end
```

Scope definitions can appear in any order — they are just named proc collections. They don't execute until called.

### Calling a Scope

Use the `call` system cog to invoke a scope:

```ruby
execute do
  call(:greeting, run: :greet) { "World" }
end
```

The `run:` keyword specifies which scope to invoke. The input block's return value becomes the scope's `scope_value`, accessible as the second parameter in that scope's cog blocks.

The first argument (`:greeting`) is the name of this call cog — used to reference its output later. If you don't need the output, you can omit it (anonymous call).

### Extracting Results with from()

The output of a `call` cog wraps an `ExecutionManager`. To extract the actual result, use `from()`:

```ruby
execute do
  call(:result, run: :my_scope) { "input" }

  # Get the scope's final output (from outputs block or last cog)
  ruby(:use_result) { from(call!(:result)) }

  # Access a specific inner cog's output
  ruby(:inner_data) do
    from(call!(:result)) { cmd!(:some_inner_cog).text }
  end
end
```

**Without a block**: `from(call!(:name))` returns the scope's `final_output` — either the value from an `outputs`/`outputs!` block, or the output of the last cog in the scope.

**With a block**: `from(call!(:name)) { ... }` evaluates the block in the **called scope's** `CogInputContext`, giving you access to that scope's cogs via `instance_exec`. The block receives `(final_output, scope_value, scope_index)` as arguments.

> **Source**: `Call::InputContext#from` at `lib/roast/system_cogs/call.rb:147–157`.

### Defining Scope Outputs

By default, a scope's final output is the output of its last cog. You can override this with `outputs` or `outputs!`:

```ruby
execute(:compute) do
  cmd(:step_a) { "echo A" }
  cmd(:step_b) { "echo B" }

  # Tolerant: accessing a skipped/failed cog returns nil
  outputs { cmd!(:step_a).text }

  # Strict: accessing a skipped/failed cog raises an exception
  outputs! { cmd!(:step_a).text }
end
```

You cannot define both `outputs` and `outputs!` in the same scope — `OutputsAlreadyDefinedError` is raised. The outputs block receives `(scope_value, scope_index)` as arguments and runs in the `CogInputContext`.

**Key behavior**: The outputs block **always runs**, even after `break!` or `next!`. It runs in the `ensure` block of `ExecutionManager.run!`. This ensures the scope always produces a final output for chaining. See Section 9 for why this matters in repeat loops.

> **Source**: `compute_final_output` at `lib/roast/execution_manager.rb:254–283`.

---

## 8. Processing Collections (map)

The `map` system cog iterates a scope over a collection of items.

### Basic Map

```ruby
execute(:process_word) do
  chat(:define) do |_, word|
    "Define the word: #{word}"
  end
end

execute do
  map(:definitions, run: :process_word) { ["hello", "world", "roast"] }
end
```

Each item in the collection becomes the `scope_value` for one invocation of the named scope. The iteration index is passed as `scope_index`.

### Setting Items Explicitly

```ruby
execute do
  map(:results, run: :process) do |my|
    my.items = ["a", "b", "c"]
    my.initial_index = 10  # first iteration gets index 10, not 0
  end
end
```

### Parallel Execution

By default, map executes serially (one item at a time). Configure parallel execution:

```ruby
config do
  map(:results) { parallel 3 }   # max 3 concurrent iterations
  # or
  map(:results) { parallel! }    # unlimited concurrency
  # or
  map(:results) { no_parallel! } # explicitly serial (default)
end
```

| Config Call | `@values[:parallel]` | Behavior |
|------------|---------------------|----------|
| _(none)_ | _(absent, fetched as 1)_ | Serial |
| `parallel(3)` | `3` | Max 3 concurrent |
| `parallel(0)` | `nil` | Unlimited concurrency |
| `parallel!` | `nil` | Unlimited concurrency |
| `no_parallel!` | `1` | Explicitly serial |

**Results are always ordered** regardless of completion order. Parallel map uses a `Hash` for thread-safe writes during concurrent execution, then reconstructs the ordered array afterward.

> **Source**: `execute_map_in_parallel` at `lib/roast/system_cogs/map.rb:306–338`. Serial at lines 288–303.

### Collecting Results with collect()

`collect()` extracts the final output from each iteration into an array:

```ruby
execute do
  map(:results, run: :process) { ["a", "b", "c"] }

  # Without block: array of each iteration's final_output
  ruby(:all) { collect(map!(:results)) }

  # With block: evaluate per-iteration in that iteration's CogInputContext
  ruby(:texts) do
    collect(map!(:results)) { chat!(:define).text }
  end
end
```

**Without a block**: Returns `[final_output_0, final_output_1, ...]`. Iterations that didn't run (due to `break!`) appear as `nil`.

**With a block**: The block is evaluated via `instance_exec` on each iteration's `CogInputContext`, receiving `(final_output, scope_value, scope_index)`. You can access any cog from within that iteration.

> **Source**: `Map::InputContext#collect` at `lib/roast/system_cogs/map.rb:375–389`.

### Reducing Results with reduce()

`reduce()` aggregates iteration outputs into a single value:

```ruby
execute do
  map(:scores, run: :compute) { items }

  ruby(:total) do
    reduce(map!(:scores), 0) do |sum, output, item, index|
      sum + output.to_i
    end
  end
end
```

The block receives `(accumulator, final_output, scope_value, scope_index)`. Return the new accumulator value.

**Nil-preservation**: If the block returns `nil`, the accumulator is **not** updated. This prevents accidental overwriting with nil. Iterations that didn't run (due to `break!`) are skipped entirely (via `.compact`).

> **Source**: `Map::InputContext#reduce` at `lib/roast/system_cogs/map.rb:426–448`.

### Accessing Individual Iterations

```ruby
# Specific iteration (0-indexed, supports negative indices)
from(map!(:results).iteration(2))

# First and last
from(map!(:results).first)
from(map!(:results).last)

# Check if iteration ran
map!(:results).iteration?(3)  # → true/false
```

Each iteration accessor returns a `Call::Output`, so you use `from()` to extract data — exactly like accessing a single `call` cog's output.

> **Source**: `Map::Output` at `lib/roast/system_cogs/map.rb:171–252`.

### Control Flow in Map

| Primitive | Serial Behavior | Parallel Behavior |
|-----------|----------------|-------------------|
| `next!` | Skip current item, continue to next | Skip current task, others continue |
| `break!` | Stop iteration, exit loop | Stop all tasks via `barrier.stop` |

Unexecuted iterations appear as `nil` entries in the output.

---

## 9. Iterative Workflows (repeat)

The `repeat` system cog runs a scope in a loop, chaining each iteration's output into the next iteration's input.

### Basic Repeat

```ruby
execute(:refine) do
  chat(:improve) do |_, draft|
    "Improve this text: #{draft}"
  end
  outputs { chat!(:improve).response }
end

execute do
  repeat(:loop, run: :refine) { "Initial rough draft" }
end
```

**Iteration chaining**: The first iteration receives `"Initial rough draft"` as its `scope_value`. The outputs block produces a refined version. That refined version becomes the `scope_value` for the second iteration, and so on.

> **Source**: `Repeat::Manager` at `lib/roast/system_cogs/repeat.rb:208–236`. The chaining is at line 228: `scope_value = em.final_output`.

### Termination

Repeat loops run indefinitely until explicitly stopped:

**break!** — Exit the loop:
```ruby
execute(:iterate) do
  ruby(:check) do |_, value, index|
    break! if index >= 5
    value + 1
  end
end
```

**max_iterations** — Safety valve:
```ruby
execute do
  repeat(:loop, run: :iterate) do |my|
    my.value = 0
    my.max_iterations = 10
  end
end
```

If `max_iterations` is reached, the loop exits normally (not via exception).

### The outputs Block Always Runs

This is a critical design point: the `outputs` block runs even on iterations where `break!` or `next!` was called. It executes in the `ensure` block of `ExecutionManager.run!`. This guarantees that every iteration produces a `final_output`, which is necessary for the chaining mechanism.

### Accessing Repeat Results

```ruby
# Final value (last iteration's final_output)
repeat!(:loop).value

# Specific iteration
from(repeat!(:loop).iteration(0))
from(repeat!(:loop).first)
from(repeat!(:loop).last)

# All iterations as a Map::Output (the Repeat→Map bridge)
collect(repeat!(:loop).results) { chat!(:improve).text }
reduce(repeat!(:loop).results, "") { |acc, output| acc + output.to_s }
```

The `.results` method returns a `Map::Output` wrapping all iterations — this is the **Repeat→Map bridge** that lets you reuse `collect` and `reduce` on repeat loop results.

> **Source**: `Repeat::Output#results` at `lib/roast/system_cogs/repeat.rb:198–199` creates `Map::Output.new(@execution_managers)`.

### State Machine Pattern

For complex iterative workflows, use a Hash as the scope value to carry state between iterations:

```ruby
execute(:guess) do
  chat(:make_guess) do |_, state|
    "The target is between 1 and 100. Previous guesses: #{state[:history].join(', ')}. Guess a number."
  end

  ruby(:update) do |_, state|
    guess = chat!(:make_guess).integer!
    history = state[:history] + [guess]
    break! if guess == state[:target]
    { target: state[:target], history: history, session: chat!(:make_guess).session }
  end

  outputs do |state|
    ruby!(:update).value
  end
end

execute do
  repeat(:game, run: :guess) do
    { target: 42, history: [], session: nil }
  end
end
```

---

## 10. Async Execution

Any cog can be configured to run asynchronously in the background.

### Configuring Async

```ruby
config do
  agent(:slow_review) { async! }
  agent(/background_/) { async! }  # regex-based
  agent { async! }                  # all agents
end
```

### Behavior

- **Async cog starts**: The cog begins executing in a background fiber. The next cog in the `execute` block starts immediately without waiting.
- **Sync cog blocks**: A sync cog (the default) blocks until it completes before the next cog starts. Sync cogs act as natural **execution barriers**.
- **Output access blocks**: Accessing an async cog's output (`agent!(:slow_review)`) blocks the current fiber until that cog completes.
- **Scope completion**: A scope does not finish until all its async cogs complete. The `@barrier.wait` at the end of `ExecutionManager.run!` ensures this.

### Async vs Parallel Map

These are different concurrency patterns:

- **Async cogs**: Different tasks running concurrently within the **same scope** (e.g., review and lint happening at the same time)
- **Parallel map**: The **same task** running concurrently on **different items** (e.g., processing 10 files simultaneously)

They can be combined: you can have async cogs inside a parallel map's scope.

> **Source**: `cog_task.wait unless cog_config.async?` at `lib/roast/execution_manager.rb:104`. Barrier wait at line 108.

### ⚠️ Control Flow Warning

`next!` and `break!` behave differently in async cogs. In particular, `next!` from an async cog is **swallowed** by the barrier handler and does not propagate to the parent scope. Only `break!` propagates reliably from async contexts. See [07-control-flow-reference.md](./07-control-flow-reference.md) for details.

---

## 11. Templates and Prompts

The `template()` method renders ERB templates for building prompts or other text:

```ruby
chat(:analyze) do
  template("analysis_prompt", files: cmd!(:ls).lines, context: "production")
end
```

### Search Priority

Given `template("greeting", name: "World")`, the framework searches for the template file in this order:

1. Absolute path as-is (if `path.absolute?`)
2. `workflow_dir / "greeting"`
3. `workflow_dir / "greeting.erb"`
4. `workflow_dir / "greeting.md.erb"`
5. `workflow_dir / "prompts" / "greeting"`
6. `workflow_dir / "prompts" / "greeting.erb"`
7. `workflow_dir / "prompts" / "greeting.md.erb"`
8. `pwd / "greeting"`
9. `pwd / "greeting.erb"`
10. `pwd / "greeting.md.erb"`
11. `pwd / "prompts" / "greeting"`
12. `pwd / "prompts" / "greeting.erb"`
13. `pwd / "prompts" / "greeting.md.erb"`

The first existing file wins. Templates are rendered with `ERB.new(content).result_with_hash(args)`.

**Known issue**: `Pathname` does not expand `~` for home directory paths (tracked in issue #663).

> **Source**: `CogInputManager#template` at `lib/roast/cog_input_manager.rb:182–223`.

### Inline Prompts

For simple prompts, use heredocs directly in the input block:

```ruby
chat(:analyze) do
  <<~PROMPT
    Analyze the following files for potential issues:
    #{cmd!(:ls).text}

    Focus on security and performance concerns.
  PROMPT
end
```

The string return is coerced into the chat's `prompt` field automatically.

---

## 12. Session Management

Sessions allow LLM conversations to be continued or forked across cogs.

### Chat Sessions

```ruby
execute do
  chat(:initial) { "What is Ruby?" }

  chat(:followup) do |my|
    my.session = chat!(:initial).session
    my.prompt = "Can you give an example?"
  end
end
```

Setting `my.session` resumes the conversation from where the previous chat left off. The new prompt is added to the existing message history.

**Fork semantics**: Sessions are deep-copied when accessed (`cog.output.deep_dup`). This means you can fork from the same point:

```ruby
# Both continue from :initial independently
chat(:branch_a) do |my|
  my.session = chat!(:initial).session
  "Tell me about Rails"
end

chat(:branch_b) do |my|
  my.session = chat!(:initial).session
  "Tell me about Sinatra"
end
```

**Cross-model**: You can resume a session with a different model than the original. The message history transfers; only the model changes.

### Agent Sessions

```ruby
execute do
  agent(:first) { "Set up the project" }

  agent(:second) do |my|
    my.session = agent!(:first).session
    my.prompts = ["Now add tests"]
  end
end
```

Agent sessions work via the CLI provider's `--fork-session` flag. The session string is a file path pointing to the serialized conversation state.

---

## 13. Common Idioms Quick-Reference

| Idiom | Example | Notes |
|-------|---------|-------|
| String return = implicit coercion | `cmd { "ls" }`, `chat { "prompt" }` | Block return value coerced to input |
| Array return for cmd = safe shell | `cmd { ["echo", user_input] }` | No shell interpolation |
| Multi-prompt agent | `agent { ["prompt 1", "prompt 2"] }` | Sequential invocations in same session |
| outputs as tolerant finalizer | `outputs { ruby!(:x).value }` | Returns nil for skipped/failed cogs |
| outputs! as strict finalizer | `outputs! { ruby!(:x).value }` | Raises for skipped/failed cogs |
| from() for scope bridging | `from(call!(:name))` | Extracts scope's final output |
| from() with block | `from(call!(:x)) { cmd!(:inner).text }` | Access inner scope's cogs |
| collect() for map results | `collect(map!(:x)) { chat!(:y).text }` | Per-iteration extraction |
| reduce() for aggregation | `reduce(map!(:x), 0) { \|sum, o\| sum + o }` | nil return preserves accumulator |
| Repeat→Map bridge | `collect(repeat!(:x).results)` | Reuses Map algebra on repeat results |
| State machine repeat | `repeat(:x, run: :y) { { state: ... } }` | Hash as scope value |
| Regex config for groups | `agent(/review_/) { async! }` | Pattern-based configuration |
| Sync cog as barrier | Place a sync cog after async ones | Blocks until all prior cogs finish |
| Template for prompts | `template("name", vars)` | 13-candidate search path |
| Session fork | `my.session = chat!(:a).session` | Deep copy = independent fork |
| tmpdir for ephemeral work | `tmpdir` → `Pathname` | Auto-created, auto-cleaned |
| Custom cog loading | `use "name"` or `use "name", from: "gem"` | See Section 14 note |

**Loading custom cogs**: Custom cogs are loaded with `use` at the top level of the workflow file (outside `config` and `execute`). Local: `use "name"` loads from `cogs/name` relative to the workflow file. From a gem: `use "name", from: "gem_name"`. See [10-writing-custom-cogs.md](./10-writing-custom-cogs.md) for details.

> **Source**: `Workflow#use` at `lib/roast/workflow.rb:105–126`.

---

## See Also

- [01-architecture-overview.md](./01-architecture-overview.md) — The architectural context for everything in this guide
- [03-cog-reference.md](./03-cog-reference.md) — Detailed per-cog reference cards (config options, input fields, output fields, defaults)
- [07-control-flow-reference.md](./07-control-flow-reference.md) — The complete sync/async propagation matrix and known edge cases
- [10-writing-custom-cogs.md](./10-writing-custom-cogs.md) — How to create your own cog types
