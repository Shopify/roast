# Document 12: Known Issues & Gotchas

> **Purpose**: Critical safety reading before modifying any part of the codebase. Everything that will trip you up — confirmed bugs, fragilities, documentation discrepancies, vestigial artifacts, and naming pitfalls.
>
> **Audience**: Everyone — intern, AI agents, new contributors. Read this before submitting your first PR.

---

## 1. Confirmed Bugs

### 1.1 Claude Dump Path Is Hardcoded

**File**: `lib/roast/cogs/agent/providers/claude/message.rb:18`

```ruby
File.write("./tmp/claude-messages.log", "#{json}\n", mode: "a") if raw_dump_file
```

The `raw_dump_file` parameter is accepted but **never used as the write target**. The write always goes to `./tmp/claude-messages.log` regardless of what path is passed. The parameter only controls whether any write occurs at all (truthiness gate).

**Impact**: Any code passing a custom dump path will silently write to the wrong location.

---

### 1.2 Top-Level Sync `next!` — Unhandled Exception

**File**: `lib/roast/workflow.rb:68`

`Workflow.start!` only rescues `ControlFlow::Break`:

```ruby
rescue ControlFlow::Break
```

A synchronous cog that calls `next!` at the top level (not inside a `map` or `repeat`) will raise `ControlFlow::Next` through `cog_task.wait` (line 104 of execution_manager.rb), and since nothing catches it, the exception propagates as an unhandled `StandardError` crash.

**Workaround**: Use `skip!` instead of `next!` at the top level. Or make the cog `async!` (which swallows `Next` in `wait_for_task_with_exception_handling`).

---

### 1.3 Repeat + Sync `next!` — Escapes Loop Entirely

**File**: `lib/roast/system_cogs/repeat.rb:230`

`Repeat::Manager` only rescues `ControlFlow::Break`:

```ruby
rescue ControlFlow::Break
```

A synchronous cog inside a `repeat` scope that calls `next!` will have the exception escape through the EM's sync `cog_task.wait`, then propagate out of `Repeat::Manager` entirely (since it doesn't rescue `Next`). Instead of advancing to the next iteration, it crashes the workflow.

**Workaround**: Make the cog async, or use `skip!` + conditional logic instead of `next!`.

---

### 1.4 Async `next!` Is Silently Swallowed

**File**: `lib/roast/execution_manager.rb:150`

```ruby
rescue ControlFlow::Next
  # TODO: do something with the message passed to next!
  @barrier.stop
```

When an async cog calls `next!`, it's caught by `wait_for_task_with_exception_handling` which stops the barrier but **does not re-raise**. This means `next!` in an async cog within a `map` or `repeat` will stop the current scope's remaining cogs but won't signal the parent to advance to the next iteration.

**Impact**: The semantic difference between sync `next!` (propagates) and async `next!` (swallowed) is undocumented and surprising. The TODO comment confirms this is a known incomplete implementation.

---

### 1.5 `outputs!` + `break!` — Exception Masking

**File**: `lib/roast/execution_manager.rb:110–114` (the `ensure` block)

When a cog calls `break!`:
1. `Break` propagates out of `run!`
2. The `ensure` block calls `compute_final_output`
3. If `outputs!` (strict mode) is configured and tries to access a cog that was skipped/never-ran due to the break, it raises `CogSkippedError`
4. The `CogSkippedError` from `ensure` **replaces** the original `Break` exception

**Impact**: The workflow appears to crash with a `CogSkippedError` rather than cleanly breaking. The root cause (`break!`) is masked.

**Workaround**: Use `outputs` (tolerant) instead of `outputs!` in scopes that may use `break!`.

---

### 1.6 Empty Scope Without `outputs` — Crash

**File**: `lib/roast/execution_manager.rb:264`

```ruby
raise CogInputManager::CogDoesNotExistError, "no cogs defined in scope" unless last_cog_name
```

If a scope contains zero cogs and no `outputs` block is defined, `compute_final_output` raises `CogDoesNotExistError`. This error is NOT caught by any internal rescue clause and crashes the workflow.

**Impact**: An empty `execute(:scope_name) do; end` followed by `call(run: :scope_name)` will crash.

---

## 2. Fragilities

### 2.1 Chat Accesses RubyLLM Internals

**File**: `lib/roast/cogs/chat.rb:55`

```ruby
temperature = chat.instance_variable_get(:@temperature)
```

The `chat` cog reaches into `RubyLLM::Chat`'s private instance variable to read the temperature. If `ruby_llm` renames or restructures this internal state, the `chat` cog silently gets `nil` temperature.

**Risk level**: Medium. Any `ruby_llm` upgrade should verify this still works.

---

### 2.2 `field` Macro Falsy-Value Bug

**File**: `lib/roast/cog/config.rb:116`

```ruby
@values[key] || default.deep_dup
```

The getter uses `||`, which means if a field is explicitly set to `false`, `nil`, or `0`, the getter returns the default instead of the stored value.

**Affected fields**: Any custom cog using `field(:name, true)` where setting the field to `false` is a valid operation. The built-in boolean options (`async!`, `abort_on_failure!`, `fail_on_error!`) all use direct `@values` manipulation to avoid this — they do NOT use the `field` macro.

**Workaround for custom cogs**: Use `@values.fetch(key, default.deep_dup)` instead of the field macro for boolean fields.

---

### 2.3 `present?` Rejects Valid Falsy Values in Coercion

**Files**:
- `lib/roast/system_cogs/call.rb:67`: `@value = input_return_value unless @value.present?`
- `lib/roast/system_cogs/repeat.rb:83`: `@value = input_return_value unless @value.present?`
- `lib/roast/system_cogs/map.rb:157`: `return if @items.present?`

ActiveSupport's `present?` returns `false` for `false`, `""`, `[]`, `{}`, and `nil`. This means:
- A `call` scope value of `false` or `""` will be overwritten by the input block's return value
- A `repeat` initial value of `false` or `""` will be overwritten
- Map items set to `[]` (empty array) will be overwritten by coercion

**Impact**: You cannot pass `false`, empty strings, or empty arrays as intentional scope values.

---

### 2.4 `instance_variable_get` Boundary Crossings

12 sites in the codebase reach across object boundaries via `instance_variable_get`:

| File | Line | Target | Purpose |
|------|------|--------|---------|
| `config_manager.rb` | 48 | `@global_config.@values` | Seed new config with global values |
| `log.rb` | 78 | `@logger.@logdev` | Check if logger is writing to a stream |
| `call.rb` | 148 | `call_cog_output.@execution_manager` | `from()` scope bridging |
| `call.rb` | 152 | `em.@scope_value` | Extract scope value for `from()` |
| `call.rb` | 153 | `em.@scope_index` | Extract scope index for `from()` |
| `map.rb` | 376 | `map_cog_output.@execution_managers` | `collect()` iteration access |
| `map.rb` | 382 | `em.@scope_value` | Per-iteration value in `collect()` |
| `map.rb` | 383 | `em.@scope_index` | Per-iteration index in `collect()` |
| `map.rb` | 427 | `map_cog_output.@execution_managers` | `reduce()` iteration access |
| `map.rb` | 434 | `em.@scope_value` | Per-iteration value in `reduce()` |
| `map.rb` | 435 | `em.@scope_index` | Per-iteration index in `reduce()` |
| `chat.rb` | 55 | `chat.@temperature` | Read RubyLLM internal state |

**Fragility assessment**: The `call.rb`/`map.rb` sites are internal (Roast accessing its own objects) so they break only if Roast itself is refactored. The `chat.rb` and `log.rb` sites depend on third-party internal structure and are genuinely fragile.

---

### 2.5 `wait` Uses Bare Rescue

**File**: `lib/roast/cog.rb:105–107`

```ruby
def wait
  @task&.wait
rescue
```

The bare `rescue` catches ALL exceptions (including `SignalException`, `SystemExit`, etc.) and silently swallows them. This means a cog that fails during async execution will appear to succeed if `wait` is called independently of `wait_for_task_with_exception_handling`.

**Impact**: Direct `cog.wait` calls (as used in `CogInputManager` for blocking output access) will never raise — the cog's failure is only visible through its state (`failed?`, `stopped?`).

---

## 3. Documentation Discrepancies

### 3.1 `abort_on_failure` Default — RESOLVED

The RBI shim previously documented `abort_on_failure` as "enabled by default" while the implementation defaulted to `false`. This has been **fixed** — the implementation now reads:

```ruby
# lib/roast/cog/config.rb:233
def abort_on_failure?
  @values.fetch(:abort_on_failure, true)
end
```

The default is now `true` (abort on failure), matching the RBI documentation.

---

## 4. Vestigial Artifacts

### 4.1 Ghost RuboCop Exclusion

**File**: `.rubocop.yml:33`

```yaml
- "lib/roast/sorbet_runtime_stub.rb"
```

This file no longer exists (`ls` confirms). The exclusion is harmless but indicates dead configuration. It was likely removed when the project migrated from `sorbet-runtime` stubs to inline RBS comments.

---

## 5. Naming & Convention Pitfalls

### 5.1 `abort_on_failure` Only Affects `FailCog`, Not Real Errors

The name suggests it controls behavior for any failure, but it **only** gates propagation of `ControlFlow::FailCog` exceptions (raised by the `fail!` DSL method). Real `StandardError` exceptions from cog execution always propagate regardless of this setting.

---

### 5.2 Anonymous Cogs: UUID Names, Can't Be Referenced

**File**: `lib/roast/cog.rb:22–23`

```ruby
def generate_fallback_name
  Random.uuid.to_sym
end
```

Cogs declared without a name (e.g., `cmd { "echo hello" }`) get a random UUID symbol as their name. They exist in the store and execute normally, but cannot be referenced by other cogs since the name is unpredictable. They are invisible to the output access API.

---

### 5.3 All CLI Kwargs Are Strings — No Type Coercion

**File**: `lib/roast/cli.rb:85–86`

```ruby
key, value = arg.split("=", 2)
kwargs[key.to_sym] = value if key
```

The `value` is always a `String`. Passing `count=5` gives you `"5"`, not `5`. Passing `verbose=true` gives you `"true"`, not `true`. Workflow authors must coerce manually:

```ruby
count = kwarg!(:count).to_i
verbose = kwarg(:verbose) == "true"
```

---

### 5.4 `demodulize` Drops ALL Namespacing — Collision Risk

**File**: `lib/roast/cog/registry.rb:65`

```ruby
cog_class_name.demodulize.underscore.to_sym
```

Loading `Billing::HttpFetch` and `Shipping::HttpFetch` both produce `:http_fetch`. The second silently overwrites the first in the registry — no warning, no error.

---

### 5.5 Reserved Method Names Block Cog Registration

Cogs cannot use names that conflict with existing methods on the context objects. The collision guard checks `respond_to?(name, true)` (the `true` includes private methods). This means names like `:send`, `:class`, `:object_id`, `:puts`, etc. will raise `IllegalCogNameError` at prepare time.

---

## 6. Deep Copy Discipline — The 13 Sites

Every boundary crossing must `deep_dup` to prevent shared-state corruption in concurrent fibers:

| # | File | Line | What's Copied | Purpose |
|---|------|------|---------------|---------|
| 1 | `execution_manager.rb` | 99 | `cog_config` | Isolate per-cog config from mutations |
| 2 | `execution_manager.rb` | 101 | `@scope_value` | Isolate per-cog scope from mutations |
| 3 | `task_context.rb` | 24 | `Fiber[:path]` | Isolate event path per fiber |
| 4 | `cog/config.rb` | 116 | `default` (in field getter) | Prevent default object sharing |
| 5 | `cog/config.rb` | 126 | `default` (in use_default!) | Same |
| 6 | `config_manager.rb` | 48 | `@global_config.@values` | Isolate new config from global mutations |
| 7 | `cog_input_manager.rb` | 78 | `.output` | Prevent consumer from mutating producer's output |
| 8 | `call.rb` | 152 | `em.@scope_value` | Isolate `from()` extraction |
| 9 | `repeat.rb` | 214 | `input.value` | Isolate next iteration's input from current |
| 10 | `chat/session.rb` | 17 | `chat.messages` | Fork session (snapshot messages) |
| 11 | `chat/session.rb` | 37 | `@messages.first(n)` | Partial session fork |
| 12 | `chat/session.rb` | 49 | `@messages.last(n)` | Partial session fork |
| 13 | `chat/session.rb` | 60 | `@messages` | Restore session to chat object |

**The invariant**: If you add a new site where data crosses from one fiber/scope/cog to another, you MUST `deep_dup` at that boundary. Forgetting this will cause intermittent, fiber-ordering-dependent data corruption that is extremely difficult to reproduce.

---

## 7. Behavioral Surprises

### 7.1 `outputs` Block Always Runs — Even After `break!`

The `outputs`/`outputs!` block inside a scope executes in the `ensure` path of `compute_final_output`. This means it runs even when `break!` terminates the scope early. If your `outputs` block accesses cogs that were skipped by the break, use `outputs` (tolerant) not `outputs!` (strict).

---

### 7.2 Sync vs Async Changes `next!` Semantics

Toggling a cog between `async!` and sync changes whether `next!` propagates to the parent scope:
- **Sync**: `next!` propagates out of the EM, signaling the parent (map/repeat) to advance
- **Async**: `next!` is swallowed by the barrier handler, only stopping the current scope

This means adding `async!` to a cog that uses `next!` will **silently break** the workflow's control flow without any error.

---

### 7.3 `from()` Without a Block Returns an Untyped Wrapper

`from(call!(:name))` without a block returns the raw `compute_final_output` result. Without `outputs`/`outputs!`, this is the last cog's `Output` object. The type is untyped — Sorbet cannot help here.

`from(call!(:name)) { agent!(:inner).response }` with a block executes in a `CogInputContext` scoped to the inner EM, giving typed access to specific cog outputs.

---

### 7.4 `map` Parallel Results Have `nil` Entries for Skipped Iterations

When a parallel map iteration calls `skip!` or `next!`, its entry in the results is `nil`. The `collect` helper preserves these nils unless filtered explicitly:

```ruby
collect(map!(:process)) { |output| output&.text }  # may contain nils
collect(map!(:process)) { |output| output&.text }.compact  # filtered
```

---

## 8. Development Environment Gotchas

### 8.1 `ROAST_WORKING_DIRECTORY` Has Dual Usage

This environment variable is used both by the CLI (to set the working directory for all cmd cogs) AND by the functional test infrastructure (to override the sandbox path). Setting it for testing purposes may inadvertently affect workflow behavior.

---

### 8.2 Tests Exclude Sorbet

Test files are excluded in `sorbet/config`. You get no type checking in tests. Mistakes in test helper type signatures are invisible until runtime.

---

### 8.3 `RECORD_VCR=true` Uses Real API Credentials

Running tests with `RECORD_VCR=true` sends real API requests. Be aware of:
- Rate limiting (OpenAI, Anthropic)
- Cost (token usage)
- Credential leakage in committed cassettes (filter sensitive data)

---

## 9. Quick-Reference: What Each Gotcha Affects

| Issue | Affects Writing Workflows | Affects Writing Cogs | Affects Framework Dev |
|-------|:---:|:---:|:---:|
| Claude dump path | | | ✓ |
| Top-level sync `next!` | ✓ | | |
| Repeat sync `next!` | ✓ | | |
| Async `next!` swallowed | ✓ | | |
| `outputs!` + `break!` | ✓ | | |
| Empty scope crash | ✓ | | |
| RubyLLM `instance_variable_get` | | | ✓ |
| `field` macro falsy values | | ✓ | |
| `present?` rejects falsy | ✓ | | |
| Anonymous cog names | ✓ | | |
| Kwargs are strings | ✓ | | |
| `demodulize` collision | | ✓ | |
| Deep copy discipline | | | ✓ |
| Sync/async `next!` divergence | ✓ | | |
| `outputs` always runs | ✓ | | |

---

## See Also

- [07-control-flow-reference.md](07-control-flow-reference.md) — Full propagation matrix for bugs 1.2–1.5
- [03-cog-reference.md](03-cog-reference.md) — `field` macro details and boolean patterns
- [05-execution-engine-internals.md](05-execution-engine-internals.md) — `compute_final_output` and `wait_for_task_with_exception_handling`
- [10-writing-custom-cogs.md](10-writing-custom-cogs.md) — Workarounds for the `field` macro
- [06-metaprogramming-map.md](06-metaprogramming-map.md) — `instance_variable_get` site catalogue
