# Roast Architecture Overview

> **Read this first.** This document provides the foundational mental model for
> the entire Roast framework. Every other document in this set assumes you've
> read and understood the concepts here.

---

## What Is Roast?

Roast is a **Ruby DSL for building structured AI workflows**. It orchestrates
four kinds of operations — shell commands, LLM conversations, AI coding agents,
and pure Ruby logic — into repeatable, composable pipelines.

It is released as the **`roast-ai`** gem (entry point: `lib/roast-ai.rb`, which
simply requires `lib/roast.rb`). Invoked via `devx roast` (Shopify internal) or
`bundle exec roast`. Source code lives at `Shopify/roast`.

Key runtime dependencies: `activesupport` (~> 8.0), `async` (>= 2.34),
`ruby_llm` (>= 1.8), `type_toolkit` (>= 0.0.5), `zeitwerk` (>= 2.6). Requires
Ruby >= 3.3.0.

All source files in `lib/` are `typed: true` under Sorbet, but the gem has **no
`sorbet-runtime` dependency** — types are enforced at development time only, via
inline `#:` RBS annotations and RBI shim files (see
[06-metaprogramming-map.md](06-metaprogramming-map.md)). This was a deliberate
architectural decision (PR #476).

---

## The Declarative Philosophy

Roast is **declarative**: you describe _what_ should happen, and the framework
decides _when_ and _how_ to execute it. This is achieved through a strict
**two-phase lifecycle**:

1. **`prepare!`** — Collect and bind. The framework reads your workflow
   definition, gathers all `config {}` and `execute {}` blocks, resolves
   configurations, and builds the execution plan. No cog actually runs yet.

2. **`start!`** — Execute. The framework walks the execution plan, running each
   cog in order, honoring async/sync settings, and producing outputs.

This is analogous to **Terraform plan/apply**, **React's virtual DOM
reconciliation**, or **Rails migration DSL** — declaration is separated from
execution so the framework can analyze, validate, and optimize the plan before
committing to side effects.

**The key implication**: All cog declarations are fixed at prepare time. The
`execute {}` block builds the cog stack during `prepare!`, not during `run!`.
You cannot conditionally create cogs at runtime. What you _can_ do is
conditionally provide input to cogs or skip them (via `skip!` in their input
blocks), but the set of cogs that _exist_ in a scope is determined before any
cog runs.

The distinction:
- **`config {}` blocks** define _what cogs look like_ (their configuration).
- **`execute {}` blocks** define _what cogs exist and in what order_ (the execution plan).
- **Input blocks** (the `{ |my| ... }` passed to each cog invocation inside
  `execute`) are **arbitrary Ruby code** that prepares a cog to run. These run at
  execution time, not at prepare time.

> **⚠️ Key Concept: What Input Blocks Really Are**
>
> An input block is NOT just "set some fields on an object." It is a full Ruby
> execution context. Its **primary** job is to populate an uninitialized Input
> instance with the values the cog needs, but you can do **any work** in it:
> set up the file system, load data, compute values, create temp files,
> transform outputs from prior cogs, etc. Think of it as a preparation phase
> where you do whatever work is needed _before_ the cog's own execution fires.
>
> For standard cogs (`cmd`, `chat`, `agent`), the cog's own execution — running
> the shell command, calling the LLM, invoking the agent CLI — happens **after**
> the input block returns and the framework validates the input.
>
> The `ruby` cog is the deliberate exception: it is a **no-op cog**. Its
> `execute` method does nothing except pass through the `value` field from its
> Input as its Output (`Output.new(input.value)`). The `ruby` cog exists so that
> you can write arbitrary Ruby code in an input block without needing a
> "real" cog underneath. All the actual work happens in the input block itself.
> It was named `ruby` (not `no-op`) because from the workflow author's
> perspective, it _looks like_ writing Ruby code that Roast executes — even
> though technically the execution is happening in the input context, not in
> `execute(input)`.

**Source**: `lib/roast/workflow.rb` — `extract_dsl_procs!` (line 134) collects
procs via `instance_eval`; `prepare!` (line 46) evaluates them into configs and
cog stacks; `start!` (line 61) runs the execution manager.

---

## The Three Evaluation Contexts

This is the single most important concept in Roast. Master this, and everything
else follows.

Roast defines **three empty classes** — `ConfigContext`, `ExecutionContext`, and
`CogInputContext` — onto which methods are **dynamically defined at runtime**
using `define_singleton_method`. Each class serves a different purpose, and **the
same method name does entirely different things depending on which context it
appears in.**

For example, calling `agent(:analyze) { ... }`:
- In a **`config {}`** block → configures the agent cog named `:analyze` (sets model, temperature, etc.)
- In an **`execute {}`** block → declares an agent cog named `:analyze` and saves the block as its input proc
- In a **cog input block** → retrieves the output of the agent cog named `:analyze` (nil-safe)

This triple-dispatch is the core of Roast's declarative design. Each context is
managed by a dedicated manager class:

### ConfigContext (`lib/roast/config_context.rb`)

**Source**: A single-line empty class: `class ConfigContext; end`.

At prepare time, `ConfigManager` defines methods on the ConfigContext instance
via `define_singleton_method` (`config_manager.rb`, lines 86–96). For each
registered cog type, a method is created that dispatches to
`ConfigManager#on_config`. When you write:

```ruby
config do
  agent(:analyze) { model "claude-sonnet-4-20250514"; temperature 0.0 }
end
```

…the `agent(:analyze)` call routes to `on_config(Agent, :analyze, block)`, which
looks up or creates the name-scoped config for `Agent` cogs named `:analyze`,
then `instance_exec`s the block against that config object (so `model "..."` and
`temperature 0.0` are method calls on an `Agent::Config` instance).

### ExecutionContext (`lib/roast/execution_context.rb`)

**Source**: A single-line empty class: `class ExecutionContext; end`.

At prepare time, `ExecutionManager` defines methods on the ExecutionContext
instance (`execution_manager.rb`, lines 186–197). For each registered cog type,
a method is created that dispatches to `ExecutionManager#on_execute`. It also
defines `outputs` and `outputs!` methods. When you write:

```ruby
execute do
  agent(:analyze) { |my| my.prompt = "Analyze this code" }
end
```

…the `agent(:analyze)` call routes to `on_execute(Agent, [:analyze], {},
block)`, which creates a new `Cog` instance with the block saved as
`@cog_input_proc` (NOT evaluated yet), then pushes the cog onto the execution
stack. **The input block runs later**, during `Cog#run!`, not during `prepare!`.

### CogInputContext (`lib/roast/cog_input_context.rb`)

**Source**: Has hardcoded control flow methods (`skip!`, `fail!`, `next!`,
`break!`) and includes `Call::InputContext` and `Map::InputContext` modules.

At construction time (which happens during `ExecutionManager#initialize`),
`CogInputManager` defines **three methods per registered cog type** on the
CogInputContext instance (`cog_input_manager.rb`, lines 40–51):
- `agent(:name)` — returns the output of the named cog, or `nil` on error (except `CogDoesNotExistError`, which always raises)
- `agent!(:name)` — returns the output or raises on any error; blocks if the cog is still running (async)
- `agent?(:name)` — returns `true`/`false`

It also defines workflow parameter accessors: `target!`, `targets`, `arg?`,
`args`, `kwarg`, `kwarg!`, `kwarg?`, `kwargs`, `tmpdir`, `template`.

And from the included modules: `from` (Call::InputContext), `collect` and
`reduce` (Map::InputContext).

### Why Three Contexts?

The separation enforces that:
- **Configuration** cannot accidentally create cogs or access outputs.
- **Declaration** cannot accidentally mutate config or access outputs.
- **Input evaluation** cannot accidentally create new cogs or change config.

Each context is a **deep module** in the Ousterhout sense — its interface is
simple (call `agent(:name) { ... }`), but behind each call is a complex dispatch
chain through the corresponding manager class. The empty class definitions and
dynamic method binding are what make this possible.

**For AI agents**: The RBI shim files (`sorbet/rbi/shims/lib/roast/`) are the
canonical documentation for every dynamically-defined method across all three
contexts. `config_context.rbi` (322 lines), `execution_context.rbi` (496 lines),
and `cog_input_context.rbi` (1,197 lines) document types, usage examples, and
cross-references for every method. See
[06-metaprogramming-map.md](06-metaprogramming-map.md) for the complete dynamic
method binding reference.

---

## The Cog Taxonomy

Every operation in Roast is a **cog** — a unit of work with a standardized
lifecycle. There are two families:

### Standard Cogs (`lib/roast/cogs/`)

| Cog | Purpose | Key Output Fields |
|-----|---------|-------------------|
| **`cmd`** | Run a shell command via `CommandRunner` | `.out`, `.err`, `.status` |
| **`chat`** | Single LLM conversation turn via `RubyLLM` | `.response`, `.session` |
| **`agent`** | AI coding agent invocation via CLI subprocess (Claude or Pi) | `.response`, `.session`, `.stats` |
| **`ruby`** | No-op cog — all work happens in the input block; `execute` just passes through `.value` | `.value` (delegates via `method_missing`) |

### System Cogs (`lib/roast/system_cogs/`)

| Cog | Purpose | Key Behavior |
|-----|---------|--------------|
| **`call`** | Invoke a named execution scope | Creates a child `ExecutionManager` for the named scope |
| **`map`** | Iterate over a collection (serial or parallel) | Creates one child EM per item; supports `Async::Semaphore` concurrency limiting |
| **`repeat`** | Loop until `break!` or `max_iterations` | Chains output → input across iterations |

All cogs share the same base lifecycle: **Config → Input → Execute → Output**.
System cogs extend this with **Params** (set at declaration time), **Manager
modules** (mixed into `ExecutionManager` to orchestrate child scopes), and
**InputContext modules** (mixed into `CogInputContext` to provide `from`,
`collect`, `reduce`).

Seven cogs are auto-registered by `Cog::Registry` on initialization
(`cog/registry.rb`, lines 24–30). Custom cogs can be added via the `use`
directive (see [10-writing-custom-cogs.md](10-writing-custom-cogs.md)).

---

## The Execution Lifecycle

Here is the complete end-to-end path from CLI invocation to workflow completion:

### Phase 0: CLI Parsing (`lib/roast/cli.rb`)

1. `CLI#execute` parses arguments, splitting at `--` into Roast flags and
   workflow arguments.
2. Workflow arguments are parsed into `WorkflowParams`: positional file
   paths/URLs → `targets`, bare words → `args` (Symbols), `key=value` pairs →
   `kwargs` (Hash).
3. `Workflow.from_file(path, params)` is called.

### Phase 1: Framework Bootstrap (`lib/roast/workflow.rb`, lines 18–30)

```
Sync do                              # Enter async event loop
  Dir.mktmpdir("roast-") do |tmpdir| # Create ephemeral workspace
    EventMonitor.start!              # Begin event processing
    workflow = Workflow.new(path, context)
    workflow.prepare!
    workflow.start!
    EventMonitor.stop!
  end                                # tmpdir auto-cleaned
end
```

`Workflow.new` reads the workflow file as a raw string, creates a fresh
`Cog::Registry` (auto-registering all 7 built-in cogs), and initializes empty
proc collection arrays.

### Phase 2: Prepare (`lib/roast/workflow.rb`, lines 46–58)

1. **`extract_dsl_procs!`**: `instance_eval(@workflow_definition)` on the
   Workflow instance. This evaluates the top-level Ruby file, which calls
   `config {}` (appending to `@config_procs`), `execute {}` (appending to
   `@execution_procs`), and `use` (registering custom cogs in the registry).
   None of the collected blocks are executed yet.

2. **`ConfigManager.prepare!`**: Binds `global` and per-cog-type methods on
   `ConfigContext`, then evaluates all `@config_procs` sequentially. Config
   objects are populated.

3. **`ExecutionManager.prepare!`**: Binds `outputs`/`outputs!` and per-cog-type
   methods on `ExecutionContext`, then evaluates all `@execution_procs`
   sequentially. This is when cog instances are created and pushed onto the cog
   stack. The `WorkflowParams` object is passed as the initial `scope_value`.

### Phase 3: Execute (`lib/roast/execution_manager.rb`, lines 87–116)

1. Enter `Sync` block, annotate the task, begin `TaskContext` tracking.
2. **Iterate the cog stack**: For each cog:
   - Resolve merged config via `ConfigManager.config_for` (4-layer cascade:
     global → type-general → regex-matched → name-specific → validate).
   - `cog.run!(barrier, config.deep_dup, input_context, scope_value.deep_dup,
     scope_index)` — creates an async task.
   - `cog_task.wait unless cog_config.async?` — sync cogs block here.
3. **`@barrier.wait`**: Process remaining async tasks via
   `wait_for_task_with_exception_handling`.
4. **`compute_final_output`**: Eagerly evaluate the `outputs`/`outputs!` block
   (or fall back to the last cog's output).
5. **`ensure`**: Stop barrier, compute final output (idempotent), end
   TaskContext, clear running flag.

---

## The Cog Lifecycle

What happens inside a single `cog.run!` call
(`lib/roast/cog.rb`, lines 71–101):

```
barrier.async(finished: false) do |task|
  TaskContext.begin_cog(self)
  @config = config
  input = self.class.input_class.new                                          # ← empty Input instance
  return_value = input_context.instance_exec(input, scope_value, scope_index, &@cog_input_proc)  # ← YOUR CODE RUNS HERE
  coerce_and_validate_input!(input, return_value)                             # ← validation + coercion
  @output = execute(input)                                                    # ← THE COG'S OWN WORK
rescue SkipCog     → @skipped = true (swallowed)
rescue FailCog     → @failed = true; re-raise if abort_on_failure?
rescue Next, Break → @skipped = true; re-raise
rescue StandardError → @failed = true; re-raise
ensure
  TaskContext.end
end
```

Note the separation: `instance_exec(..., &@cog_input_proc)` runs **your** input
block code. Then `execute(input)` runs **the cog's** work. For `cmd`, `chat`, and
`agent`, these are very different phases. For the `ruby` cog, `execute(input)` is
`Output.new(input.value)` — a literal no-op — so all meaningful work happens in
the input block.

### Two-Phase Input Validation

1. **`validate!`** is called first (optimistic — maybe the input block set all
   fields directly via `my.prompt = "..."`).
2. If `InvalidInputError`: **`coerce(return_value)`** is called — this attempts
   to interpret the block's return value (e.g., a returned string becomes the
   prompt).
3. **`validate!`** is called again (mandatory — if still invalid, the cog fails).

This two-phase design (`cog.rb`, lines 149–157) means workflow authors can
either set fields explicitly (`my.prompt = "..."`) or return a value from the
block (`{ "analyze this" }`) — both work.

---

## Concurrency Model

Roast uses **fiber-based cooperative concurrency** via the `async` gem. There are
no threads and no mutexes.

- **`Async::Barrier`** manages groups of concurrent tasks within each
  `ExecutionManager`. One barrier per EM instance.
- **Sync cogs** block the iteration loop: `cog_task.wait` is called immediately
  after `cog.run!`, so the next cog doesn't start until the current one finishes.
- **Async cogs** (`config { agent(:name) { async! } }`) run in the background.
  The iteration loop continues to the next cog immediately. Output access
  (`agent!(:name)`) blocks until the async cog completes.
- **Parallel map** uses `Async::Semaphore` for concurrency limiting
  (`map.rb`). `parallel(5)` runs up to 5 iterations concurrently;
  `parallel!` runs all items concurrently.

### Deep Copy Discipline

Because multiple fibers may share the same objects, Roast applies `deep_dup` at
every boundary where data crosses between contexts. There are **12 identified
`deep_dup` sites** serving 5 purposes:
- **Config isolation**: Prevent one cog from mutating config shared by others.
- **Scope value isolation**: Prevent one cog from mutating the scope value seen
  by subsequent cogs.
- **Output isolation**: Prevent downstream cogs from mutating shared output
  (`cog_input_manager.rb`, line 78).
- **Event path isolation**: Snapshot fiber-local path at event creation time.
- **Session fork isolation**: Deep copy chat session messages for fork semantics.

This is analogous to **Erlang's message-passing** — isolation by copying, not
sharing.

### ⚠️ Critical: The Sync/Async Next Divergence

This is the most subtle and important behavioral difference in the framework:

- **Sync cog calls `next!`**: The exception flows through `cog_task.wait` →
  exits the cog stack loop → propagates OUT of `run!` to the parent scope
  (Map/Repeat manager).
- **Async cog calls `next!`**: The exception is caught in
  `wait_for_task_with_exception_handling` → barrier is stopped → exception is
  **swallowed**. The scope ends normally.
- **`break!` always propagates** regardless of sync/async.

This divergence is an unavoidable consequence of cooperative concurrency: async
exceptions are "out-of-band" — they happen in a different fiber, and the only
way to communicate them back is through the barrier wait handler. See
[07-control-flow-reference.md](07-control-flow-reference.md) for the complete
propagation matrix.

---

## Analogies to Other Systems

| Roast Pattern | Analogy | Shared Principle |
|---|---|---|
| `config {}`/`execute {}` collection → `prepare!` → `start!` | Terraform plan/apply | Separate declaration from execution |
| `deep_dup` at every boundary | Erlang message-passing | Isolation by copying, not sharing |
| Flat scope namespace (`execute(:name)` callable from any depth) | CSS selectors, Make targets | Global addressability, no lexical scoping |
| Three evaluation contexts | DSL-specific MVC | Different views of the same entity per responsibility |
| JSON/number candidate extraction in Output mixins | Framework absorbs complexity | "Pulling complexity downwards" (Ousterhout) |
| Config merge cascade (global → type → regex → name) | CSS specificity | More-specific rules override less-specific |

---

## Where to Go Next

- **[02-dsl-users-guide.md](02-dsl-users-guide.md)** — How to write Roast
  workflows (practical usage)
- **[03-cog-reference.md](03-cog-reference.md)** — Detailed per-cog reference
  cards
- **[06-metaprogramming-map.md](06-metaprogramming-map.md)** — The complete
  dynamic method binding reference (critical for AI agents)
- **[07-control-flow-reference.md](07-control-flow-reference.md)** — The full
  control flow propagation matrix
- **Tutorial chapters** in the repo's tutorial directory cover hands-on basics
  (ch1–ch9)
