# Document 4: Design Philosophy

_Why the framework is built the way it is._

This document connects Roast's implementation decisions to software design principles and the architectural reviews that shaped them. It answers "why?" for every major pattern you'll encounter in the codebase.

---

## 1. Declarative-First: Separate Declaration from Execution

### The Principle

Roast workflows are **declarative**: you describe _what_ should happen, and the framework decides _how_ and _when_ to execute it. This is enforced by the two-phase lifecycle:

1. **Prepare** (`prepare!`) — Collect all declarations. Build the complete plan.
2. **Start** (`start!`) — Execute the plan sequentially.

You cannot conditionally create cogs at runtime. The cog stack is fixed once `prepare!` completes. Input blocks (the `{ |my| ... }` passed to each cog call) run at execution time and _can_ be conditional — but the cog itself always exists.

### Why This Design

**Predictability over flexibility.** If cog creation were conditional on runtime data, the framework couldn't guarantee:
- That output references (`cmd!(:name)`) always resolve to a known cog
- That the config cascade is complete before any cog runs
- That async barriers know the full set of tasks they're managing

The trade-off is that workflows can't dynamically branch. Instead, they use input-block `skip!` to bypass cogs that shouldn't execute in a given run.

### The Terraform Analogy

| Phase | Terraform | Roast |
|-------|-----------|-------|
| Collect | `.tf` file parsing | `extract_dsl_procs!` — `instance_eval` on workflow file |
| Plan | `terraform plan` | `ConfigManager.prepare!` + `ExecutionManager.prepare!` |
| Apply | `terraform apply` | `ExecutionManager.run!` |

Source: `workflow.rb:46–58` (prepare!), `workflow.rb:61–73` (start!), `workflow.rb:134–136` (extract_dsl_procs!)

### Why `extract_dsl_procs!` Doesn't Evaluate

`workflow.rb:135` calls `instance_eval(@workflow_definition, ...)` on the Workflow instance. This runs the top-level workflow file — but the only methods available at that level are `config`, `execute`, and `use`. These methods _collect_ blocks into arrays (`@config_procs`, `@execution_procs`) without evaluating any of them. The actual evaluation happens later during each manager's `prepare!` call, when the blocks are `instance_eval`'d against the appropriate context.

This two-stage collection ensures that all `use` declarations (which register custom cogs) complete before any config or execute block tries to reference them.

---

## 2. Deep Copy at Every Boundary

### The Principle

Every time data crosses a component boundary, it is `deep_dup`'d. This gives each component an **independent copy** that can be mutated freely without affecting any other component.

### The Complete Catalogue (13 sites, 5 purposes)

**Config isolation (4 sites):**

| Site | File:Line | Purpose |
|------|-----------|---------|
| Field getter fallback | `cog/config.rb:116` | `@values[key] \|\| default.deep_dup` — prevent mutation of class-level default |
| Field reset | `cog/config.rb:126` | `@values[key] = default.deep_dup` — same protection via `use_default_!` |
| Global values seeding | `config_manager.rb:48` | `@global_config.instance_variable_get(:@values).deep_dup` — isolate each cog's config from global |
| Config to cog | `execution_manager.rb:99` | `cog_config.deep_dup` — cog receives its own config copy |

**Scope isolation (3 sites):**

| Site | File:Line | Purpose |
|------|-----------|---------|
| Scope value to cog | `execution_manager.rb:101` | `@scope_value.deep_dup` — parallel cogs can't corrupt shared scope |
| Repeat iteration chaining | `system_cogs/repeat.rb:214` | `input.value.deep_dup` — iteration N+1 gets a clean copy of N's output |
| `from()` helper | `system_cogs/call.rb:152` | `em.instance_variable_get(:@scope_value).deep_dup` — consumer can't mutate producer's scope |

**Output isolation (1 site):**

| Site | File:Line | Purpose |
|------|-----------|---------|
| Output access | `cog_input_manager.rb:78` | `.output.deep_dup` — every accessor call returns an independent copy |

**Event path isolation (1 site):**

| Site | File:Line | Purpose |
|------|-----------|---------|
| Fiber path snapshot | `task_context.rb:24` | `Fiber[:path]&.deep_dup \|\| []` — event carries immutable path snapshot |

**Session fork isolation (4 sites):**

| Site | File:Line | Purpose |
|------|-----------|---------|
| From chat | `cogs/chat/session.rb:17` | `chat.messages.deep_dup` — new Session doesn't share message array |
| First N | `cogs/chat/session.rb:37` | `@messages.first(n).deep_dup` — truncated session is independent |
| Last N | `cogs/chat/session.rb:49` | `@messages.last(n).deep_dup` — same |
| Apply to chat | `cogs/chat/session.rb:60` | `@messages.deep_dup` — restoring a session doesn't consume it |

### The Erlang Analogy

This pattern mirrors Erlang's message-passing semantics: processes (fibers, in Roast) never share mutable state. Communication happens by copying data at every boundary. The cost is memory; the benefit is **total isolation without locks**. Since Roast uses cooperative (fiber-based) concurrency, there are no mutexes, no thread-safety concerns, no race conditions — as long as the deep copy discipline is maintained.

### The Invariant

**If you add a new boundary crossing where data flows between components, you must `deep_dup` at that boundary.** Violating this invariant will produce subtle bugs that only manifest under parallel execution.

---

## 3. Config Layering & Nilability

### Value Absence vs Value Presence

The config merge cascade relies on a critical distinction: **a key that was never set** (absent from the `@values` hash) vs **a key that was explicitly set** (present, even if the value is `nil`). 

`Config#merge` (`cog/config.rb:47`) uses `Hash#merge`, which only overwrites keys present in the incoming hash. If a cog-type config never calls `model "gpt-4"`, the `:model` key is absent, and the global value flows through. If it explicitly calls `model "gpt-4"`, the key is present and overrides.

This enables the CSS-like specificity cascade:

```
global → cog-type-general → regexp-matched → name-specific → validate!
```

Each layer only contributes the keys it explicitly sets. Everything else is inherited from the less-specific layer.

### The `field` Macro's Falsy-Value Limitation

`cog/config.rb:116`: `@values[key] || default.deep_dup`

This means `false` and `nil` values fall through to the default. The built-in boolean configs (`async!`, `abort_on_failure!`) work around this by manipulating `@values` directly without going through the `field` macro. Custom cogs that need boolean fields should follow the same pattern.

### Why `instance_variable_get` for Global Config?

`config_manager.rb:48` uses `@global_config.instance_variable_get(:@values)` despite `Config` having a public `attr_reader :values` (config.rb:30). This is a vestigial pattern from before the accessor existed. It still works correctly but is technically redundant.

---

## 4. Three Contexts as "Deep Modules"

### Ousterhout's Principle (A Philosophy of Software Design, Ch. 4)

A "deep module" has a simple interface that hides substantial complexity. The three evaluation contexts in Roast are exemplary deep modules:

| Context | Interface | Hidden Complexity |
|---------|-----------|-------------------|
| `ConfigContext` | `agent(:name) { model "gpt-4o" }` | Dispatches through `ConfigManager.on_config`, resolves to correct config store (general/regexp/named), evaluates block via `instance_exec` against the config object |
| `ExecutionContext` | `agent(:name) { \|my\| my.prompt = "..." }` | Dispatches through `ExecutionManager.on_execute`, distinguishes standard cogs from system cogs, creates appropriate instances, saves input blocks, pushes to cog stack |
| `CogInputContext` | `agent!(:name).response` | Dispatches through `CogInputManager.cog_output!`, resolves cog from store, calls `wait` (blocking if async), validates state, returns `output.deep_dup` |

The workflow author sees one simple API: call a cog-type method with a name and a block. The three contexts route that identical-looking call to completely different operations based on _where_ it appears in the workflow.

### Why Blank Classes?

`ConfigContext`, `ExecutionContext`, and `CogInputContext` are intentionally blank at the class level. All their methods are installed dynamically via `define_singleton_method` during `prepare!`. This means:

1. **No method exists until it's needed** — typos produce clear `NoMethodError` at eval time
2. **The method set is customizable** — custom cogs automatically get their own methods in all three contexts via the Registry → bind loop
3. **IDE/Sorbet support** is provided via RBI shims that document the dynamic methods

---

## 5. Pulling Complexity Downwards

### Ousterhout's Principle (Ch. 7)

"Pull complexity downwards": modules should absorb complexity on behalf of their consumers, even if it makes the module's implementation harder.

**JSON extraction** (`cog/output.rb:55–131`): `WithJson#json!` doesn't just call `JSON.parse`. It tries:
1. The entire output string
2. `` ```json `` code blocks (last first)
3. Bare `` ``` `` code blocks (last first)
4. Any-language code blocks (last first)
5. `{ }` and `[ ]` patterns (longest first)

The "last first" ordering exists because LLMs tend to refine their output — the final JSON block in a response is most likely to be the correct one.

**Number extraction** (`cog/output.rb:214–261`): `WithNumber#float!` scans bottom-up because LLMs often explain their reasoning before stating a final answer. It strips currency symbols, digit separators, and validates against a strict regex before calling `Float()`.

The workflow author simply calls `.json` or `.integer`. The framework absorbs all the messy reality of LLM output parsing.

---

## 6. Error Hierarchy as Information Hiding

### Consumer-Side vs Producer-Side Errors

The error hierarchy embodies a deliberate separation:

- **`CogError`** (producer-side): something went wrong _inside_ a cog (e.g., `CogAlreadyStartedError`). These are programming errors in the framework itself.
- **`CogOutputAccessError`** (consumer-side): something went wrong when _another component_ tried to access a cog's output. These are workflow-level conditions.

`CogOutputAccessError` is NOT a subclass of `CogError`. This is intentional: `rescue CogError` catches only producer bugs. Consumer-side errors require their own handling.

The consumer-side hierarchy further separates:
- `CogDoesNotExistError` — always fatal (programming error, raised even in tolerant mode)
- `CogNotYetRunError`, `CogSkippedError`, `CogStoppedError` — swallowed by `outputs`, raised by `outputs!`
- `CogFailedError` — always propagates (never swallowed by either variant)

---

## 7. Flat Scope Namespace

Execution scopes (`execute(:name) { ... }`) are **globally addressable**. A `call(:x, run: :my_scope)` at any depth can invoke any named scope defined at the top level. Scopes are not lexically nested — there's no concept of "local scope."

### Why?

1. **Reusability**: The same scope can be called from multiple places (map, repeat, or direct call)
2. **Simplicity**: No scope resolution rules, no shadowing, no inheritance chains
3. **Predictability**: Every scope name resolves to exactly one definition

### Trade-off

The risk is naming collisions. With a flat namespace, two scopes with the same name overwrite silently (the `@execution_procs[scope]` array just accumulates). This is analogous to CSS selectors or Make targets — simple addressing at the cost of global uniqueness discipline.

---

## 8. Composition over Inheritance

### The Repeat→Map Output Bridge

`Repeat::Output#results` returns a `Map::Output` instance, wrapping the repeat's execution managers in map's collection interface. This means `collect()` and `reduce()` work identically on both map and repeat results.

Rather than making Repeat inherit from Map or extracting a shared base class, the framework composes: Repeat's output _contains_ a Map output. The implementation is a one-line delegation that avoids duplicating collection logic.

### Mixin Modules for Output Parsing

`WithText`, `WithJson`, and `WithNumber` are modules that any cog can include. They compose with each other (a single output class can include all three) and with the cog's own output fields. The only contract: implement `raw_text` (private method returning the string to parse).

---

## 9. Architectural Decisions Traced to Reviews

### PR #485 — Fiber-Based Cooperative Concurrency

Juniper mandated cooperative (fiber-based) concurrency over threads, with no default timeouts. This created the `Async::Barrier` model where cogs yield control voluntarily. The implication: the framework can never forcibly terminate a running cog. `break!` sets a flag and `barrier.stop` cancels pending tasks — but a cog in the middle of an HTTP request will complete before yielding.

This is also why the sync/async `next!` divergence exists: `barrier.wait` is the only place where async exceptions are caught, so `next!` from an async cog gets swallowed at that boundary rather than propagating to the parent scope.

### PR #428 — Config-Block-First

Juniper rejected XDG_CONFIG_HOME, global config files, and environment-based configuration for cog behavior. All cog config belongs inside the workflow DSL. The only external config source is `ROAST_WORKING_DIRECTORY` (CLI-level, not cog-level). This keeps workflows self-contained and reproducible.

### PR #476 — No sorbet-runtime in the DSL Layer

Roast uses `typed: true` with inline RBS annotations (`#:`) and RBI shims for IDE support, but has zero `sorbet-runtime` dependency. Types are checked at development time (via `srb tc`) but never at runtime. `type_toolkit` provides lightweight runtime utilities. The rationale: runtime type checking in a DSL layer adds overhead and confusing error messages for workflow authors.

### PR #783 — No Mutable Objects in Config @values

Juniper rejected storing provider instances (mutable objects) in config `@values`. Config values must be primitives and strings only. The agent cog's provider is memoized on the Cog instance itself (`@provider ||= ...`), not in config. This ensures config remains copyable (via `deep_dup`) and serializable.

---

## 10. The Four Workflow Archetypes

Every Roast workflow maps to one of four structural patterns:

### Pipeline

Sequential processing: each cog's output feeds the next cog's input.

```
cmd(:fetch) → chat(:analyze) → cmd(:write)
```

Most workflows are pipelines. The cog stack is executed in order, and input blocks reference earlier outputs via `cmd!(:fetch).text`.

### Fan-Out / Fan-In (Map-Reduce)

Parallel processing of a collection, with aggregation:

```
cmd(:list) → map(:process, run: :item_scope) → outputs { reduce(map!(:process), ...) }
```

The `map` system cog fans out to N parallel executions. `collect()` and `reduce()` fan back in.

### Iterative Refinement (Repeat)

Loop until a condition is met, with each iteration refining the previous output:

```
repeat(:refine, run: :improve_step) { initial_draft }
```

State flows forward: output of iteration N becomes scope_value of iteration N+1. `break!` terminates.

### Multi-Model Composition

Different cogs use different AI models for different tasks within the same workflow:

```
config {
  chat(:draft) { model "gpt-4o" }
  agent(:review) { provider :claude }
  chat(:summarize) { model "gpt-4o-mini" }
}
```

The config cascade enables per-cog model selection. Sessions can be forked between models (deep-copied message arrays applied to new providers).

---

## Summary of Design Principles

| Pattern | Principle | Source |
|---------|-----------|--------|
| Two-phase lifecycle | Separate declaration from execution | Terraform plan/apply |
| Deep copy at boundaries | Isolation without locks | Erlang message-passing |
| Config merge cascade | Specificity-based override | CSS cascade |
| Three blank contexts | Deep modules (simple interface, complex internals) | Ousterhout Ch. 4 |
| Output parsing mixins | Pull complexity downwards | Ousterhout Ch. 7 |
| Error hierarchy split | Consumer vs producer boundaries | Information hiding |
| Flat scope namespace | Global addressability | Make targets, CSS selectors |
| Repeat→Map bridge | Composition over inheritance | GoF, SOLID |
| No mutable config | Copyable, serializable state | Immutability discipline |
| Fiber-based concurrency | Cooperative scheduling, no locks | PR #485 |
| Config-block-first | Self-contained workflows | PR #428 |
| No sorbet-runtime | Dev-time checks, no runtime overhead | PR #476 |
| Primitives-only config | Deep-dup safety | PR #783 |
