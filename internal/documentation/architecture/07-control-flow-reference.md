# Document 7: Control Flow Reference

> **Audience**: AI coding agents and developers working on or with Roast internals.
> **Purpose**: Exhaustive reference for the exception-based control flow system, including the complete propagation matrix, sync/async divergence, output access semantics, and known edge cases.
> **Source version**: Roast 1.1.0 (verified May 2026)

---

## 1. The ControlFlow Exception Hierarchy

All control flow signals inherit from `ControlFlow::Base < StandardError`, which is a **separate** hierarchy from `Roast::Error`. This separation is intentional: control flow signals are not errors — they are structured workflow directives.

**Source**: `lib/roast/control_flow.rb:1–39`

```
ControlFlow::Base < StandardError
├── SkipCog     — terminate this cog, mark it skipped (line 11)
├── FailCog     — terminate this cog, mark it failed  (line 16)
├── Next        — terminate the current scope/iteration, advance (line 25)
└── Break       — terminate the current scope/iteration AND all subsequent iterations (line 37)
```

### Summary Table

| Exception  | Raised By | Cog State Set | Propagation Rule |
|------------|-----------|---------------|------------------|
| `SkipCog`  | `skip!(msg)` in input/execute blocks | `@skipped = true` | **Never** re-raised from `Cog#run!` |
| `FailCog`  | `fail!(msg)` in input/execute blocks; `CommandRunner` when `fail_on_error?` | `@failed = true` | Re-raised **only if** `config.abort_on_failure?` (default: `true`) |
| `Next`     | `next!(msg)` in input/execute blocks | `@skipped = true` | **Always** re-raised from `Cog#run!` |
| `Break`    | `break!(msg)` in input/execute blocks | `@skipped = true` | **Always** re-raised from `Cog#run!` |

**Key distinction**: `SkipCog` and `FailCog` are **cog-scoped** — they affect only the current cog. `Next` and `Break` are **scope-scoped** — they affect the entire execution scope (all subsequent cogs in the scope are abandoned).

---

## 2. Layer-by-Layer Propagation

Control flow exceptions pass through four distinct layers, each with its own catch/propagate policy. Understanding these layers is the key to understanding Roast's runtime behavior.

### Layer 1: Cog.run!

**Source**: `lib/roast/cog.rb:71–101`

This is the innermost boundary. Every exception raised during cog input evaluation or execution is first caught here.

```ruby
# Simplified from lib/roast/cog.rb:84–101
rescue ControlFlow::SkipCog
  @skipped = true
  # SWALLOWED — does not propagate
rescue ControlFlow::FailCog => e
  @failed = true
  raise e if config.abort_on_failure?   # conditional propagation
rescue ControlFlow::Next, ControlFlow::Break => e
  @skipped = true
  raise e                                # ALWAYS propagates
rescue StandardError => e
  @failed = true
  raise e                                # ALWAYS propagates
```

**Important**: The cog runs inside a `barrier.async(finished: false)` task (line 74). When an exception is re-raised here, it becomes the task's result. How it surfaces to the parent depends on whether the cog is synchronous or asynchronous — this is Layer 2.

### Layer 2: ExecutionManager.run!

**Source**: `lib/roast/execution_manager.rb:87–116`

This is where the critical **sync/async divergence** occurs. The `run!` method iterates the cog stack and has two distinct exception paths.

#### Sync Path (line 104)

```ruby
cog_task.wait unless cog_config.async?
```

For synchronous cogs, `cog_task.wait` is called **immediately** after `cog.run!` returns the task. This call surfaces any exception the task raised, **directly in the cog stack iteration loop**. The exception propagates through the `@cog_stack.each` block, hits the `ensure` clause (line 110), and then propagates **out of `run!`** to the parent.

#### Async Path (line 108)

```ruby
@barrier.wait { |task| wait_for_task_with_exception_handling(task) }
```

For asynchronous cogs, the exception surfaces later, when the barrier drains completed tasks. The handler at line 148 determines what happens:

```ruby
# lib/roast/execution_manager.rb:148–160
def wait_for_task_with_exception_handling(task)
  task.wait
rescue ControlFlow::Next
  @barrier.stop           # scope ends normally — Next is SWALLOWED
rescue ControlFlow::Break => e
  @barrier.stop
  compute_final_output    # eagerly compute before re-raising
  raise e                 # Break is RE-RAISED
rescue StandardError => e
  @barrier.stop
  raise e                 # errors are RE-RAISED
end
```

**The divergence**: For sync cogs, `Next` propagates out of `run!` (just like `Break`). For async cogs, `Next` is swallowed but `Break` propagates. This is the single most important behavioral distinction in the entire framework.

#### The `ensure` Clause (lines 110–115)

Regardless of how `run!` exits (normally or via exception), the `ensure` block always runs:

```ruby
ensure
  @barrier.stop           # cancel any still-running async cogs
  compute_final_output    # set @final_output (idempotent)
  TaskContext.end          # clean up fiber-local path
  @running = false
```

This guarantees that `final_output` is always computed, even when `break!` or an error terminates execution early.

### Layer 3: System Cog Managers

Each system cog type wraps `ExecutionManager.run!` with its own catch policy.

#### Call::Manager

**Source**: `lib/roast/system_cogs/call.rb:106–113`

```ruby
em.prepare!
begin
  em.run!
rescue ControlFlow::Next, ControlFlow::Break
  # both swallowed — inner scope ends early, returns Output.new(em) normally
end
Output.new(em)
```

**Behavior**: Both `Next` and `Break` are treated identically — they simply end the called scope early. The call cog always returns normally to its parent scope.

#### Map::Manager — Serial

**Source**: `lib/roast/system_cogs/map.rb:288–303`

```ruby
input.items.each_with_index do |item, index|
  ems << em = create_execution_manager_for_map_item(...)
  em.prepare!
  em.run!
rescue ControlFlow::Next
  # swallowed — loop continues to next item
rescue ControlFlow::Break
  break  # exits the each_with_index loop
end
```

**Behavior**: `Next` advances to the next collection item. `Break` exits the entire map loop. Both are handled cleanly.

#### Map::Manager — Parallel

**Source**: `lib/roast/system_cogs/map.rb:306–338`

```ruby
# Per-task (inside barrier.async):
em.prepare!
em.run!
rescue ControlFlow::Next
  # swallowed per-task — other parallel tasks continue

# Barrier wait:
barrier.wait do |task|
  task.wait
rescue ControlFlow::Break
  barrier.stop            # terminates all parallel tasks
rescue StandardError => e
  barrier.stop
  raise e
end
```

**Behavior**: `Next` is caught per-task (other iterations continue). `Break` stops all parallel iterations via the barrier. Note that `Next` from a sync cog inside a parallel map iteration propagates out of `em.run!` and is caught by the per-task rescue on line 316.

#### Repeat::Manager

**Source**: `lib/roast/system_cogs/repeat.rb:216–233`

```ruby
loop do
  ems << em = ExecutionManager.new(...)
  em.prepare!
  em.run!
  scope_value = em.final_output
  break if max_iterations.present? && ems.length >= max_iterations
rescue ControlFlow::Break
  break  # exits the loop
end
Output.new(ems)
```

**⚠️ Critical**: There is **no** `rescue ControlFlow::Next` clause. This has different consequences depending on sync/async:

- **Async cog calls `next!`**: The inner `ExecutionManager` swallows it (Layer 2 async path). The iteration completes with whatever `final_output` was computed. The loop continues normally. **This is the expected behavior.**
- **Sync cog calls `next!`**: The inner `ExecutionManager` propagates it (Layer 2 sync path). The `Next` exception **escapes** the repeat loop entirely, propagating to the parent scope. **This is a known bug** (see Section 7).

### Layer 4: Workflow.start!

**Source**: `lib/roast/workflow.rb:61–73`

```ruby
begin
  @execution_manager.run!
rescue ControlFlow::Break
  # treat break! as graceful termination
end
@completed = true
```

**⚠️ Critical**: There is **no** `rescue ControlFlow::Next`. Same consequences as Repeat:

- **Async cog calls `next!` at top level**: Swallowed by the EM's barrier handler. Workflow ends normally.
- **Sync cog calls `next!` at top level**: `Next` escapes `Workflow.start!` as an unhandled exception. **This is a known bug** (see Section 7).

---

## 3. The Sync/Async Divergence — Why It Exists

This is not a bug in the design. It is an **unavoidable consequence** of fiber-based cooperative concurrency.

When a **synchronous** cog raises `Next`, the exception flows "in-band" — through the normal Ruby call stack. `cog_task.wait` on line 104 surfaces it immediately in the same fiber as `ExecutionManager.run!`, and it propagates naturally through the `@cog_stack.each` loop.

When an **asynchronous** cog raises `Next`, the exception is "out-of-band" — it occurs in a different fiber. The only mechanism to communicate it back is through the barrier's task completion handler (`wait_for_task_with_exception_handling`). This handler **cannot** re-raise `Next` into the parent fiber context in a way that would skip remaining stack entries — the parent fiber is in the middle of `@barrier.wait`, not `@cog_stack.each`. So `Next` is swallowed, and the barrier is stopped to prevent further async work.

The architectural consequence: **`Next` is reliable only in async cogs or serial map iterations.** For sync cogs in repeat loops or at the top level, `Next` propagates beyond its intended scope.

---

## 4. Complete Propagation Matrix

This is the definitive reference. Each cell describes what happens when the given exception is raised by a cog in the given context.

### SkipCog

| Context | Behavior |
|---------|----------|
| Any cog (sync or async) | Swallowed in `Cog#run!` (line 84). Cog marked `@skipped = true`. No propagation. |
| `outputs` / `outputs!` block | Not raised by control flow — but see `CogSkippedError` in Section 5. |

### FailCog

| Context | `abort_on_failure? = false` | `abort_on_failure? = true` (default) |
|---------|----------------------------|--------------------------------------|
| Any cog | Swallowed in `Cog#run!` (line 88). Cog marked `@failed = true`. | Re-raised from `Cog#run!` (line 92). Propagates as `StandardError` through all layers. |
| Call scope | N/A | Not caught by Call::Manager — propagates to parent. |
| Map (serial) | N/A | Not caught by Map serial — propagates out of map. |
| Map (parallel) | N/A | Caught by barrier `rescue StandardError` (line 329) — barrier stops, re-raised. |
| Repeat | N/A | Not caught by Repeat::Manager — propagates out of repeat. |
| Top-level | N/A | Not caught by `Workflow.start!` — **unhandled exception**. |
| `outputs` block | N/A | `FailCog` is **not** in `compute_final_output`'s rescue clause — always propagates. |

### Next

| Context | Sync Cog | Async Cog |
|---------|----------|-----------|
| **In Call** | Propagates from `em.run!` → caught by Call::Manager (line 108). Scope ends early, returns normally. | Swallowed by inner EM's barrier handler (line 150). Scope ends normally. |
| **In Map (serial)** | Caught by `rescue ControlFlow::Next` (line 294). Loop advances to next item. | N/A (serial mode = all cogs are sync within each iteration's EM). |
| **In Map (parallel)** | Propagates from `em.run!` → caught by per-task `rescue ControlFlow::Next` (line 316). Other iterations continue. | Swallowed by inner EM's barrier handler. Task ends normally. Other iterations continue. |
| **In Repeat** | ⚠️ Propagates from `em.run!` → **NOT caught** by Repeat::Manager → **escapes repeat entirely** to parent scope. | Swallowed by inner EM's barrier handler. Iteration ends normally. `final_output` feeds next iteration. Loop continues. |
| **Top-level** | ⚠️ Propagates from `em.run!` → **NOT caught** by `Workflow.start!` → **unhandled exception**. | Swallowed by EM's barrier handler. Workflow ends normally. |
| **In `outputs` block** | Caught by `compute_final_output` rescue (line 268). `final_output = nil`. | Same. |

### Break

| Context | Sync Cog | Async Cog |
|---------|----------|-----------|
| **In Call** | Propagates from `em.run!` → caught by Call::Manager (line 108). Scope ends early, returns normally. | Re-raised by EM barrier handler (line 155) → caught by Call::Manager. Same result. |
| **In Map (serial)** | Caught by `rescue ControlFlow::Break` (line 297). Loop exits via `break`. | N/A (serial). |
| **In Map (parallel)** | Propagates from `em.run!` → ⚠️ goes to per-task fiber, not caught per-task → raised during `barrier.wait` → caught (line 326). Barrier stops. | Re-raised by inner EM barrier handler → caught by outer map `barrier.wait` (line 326). Barrier stops. |
| **In Repeat** | Caught by `rescue ControlFlow::Break` (line 231). Loop exits. | Re-raised by inner EM barrier handler → caught by Repeat (line 231). Loop exits. |
| **Top-level** | Caught by `Workflow.start!` (line 68). Graceful termination. | Re-raised by EM barrier handler → caught by `Workflow.start!`. Graceful termination. |
| **In `outputs` block** | ⚠️ **NOT caught** by `compute_final_output` — propagates through the `ensure` block. See Section 6. | Same. |

---

## 5. Output Access Semantics

When a cog input block or `outputs` block accesses another cog's output, a separate error hierarchy governs what happens.

### The CogOutputAccessError Hierarchy

**Source**: `lib/roast/cog_input_manager.rb:7–17`

```
CogOutputAccessError < Roast::Error      (NOT under ControlFlow::Base!)
├── CogDoesNotExistError     — no cog with that name was ever declared
├── CogNotYetRunError        — cog exists but hasn't completed yet
├── CogSkippedError          — cog was skipped (via skip!, next!, or break!)
├── CogFailedError           — cog failed (via fail! or unhandled StandardError)
└── CogStoppedError          — cog's Async task was externally stopped
```

**Design note**: This hierarchy is under `Roast::Error`, not `ControlFlow::Base`. Output access errors are **consumer-side** errors (the code trying to read the output encounters a problem), whereas control flow exceptions are **producer-side** signals (the code running the cog decides to skip/fail/advance).

### The Three Accessor Methods

**Source**: `lib/roast/cog_input_manager.rb:54–79`

| Method | Blocks on async? | On error | Returns |
|--------|-------------------|----------|---------|
| `cog_type(:name)` (tolerant) | No | Catches all `CogOutputAccessError` **except** `CogDoesNotExistError` → returns `nil` | `Cog::Output?` |
| `cog_type!(:name)` (strict) | **Yes** — calls `cog.wait` (line 73) | Raises `CogSkippedError`, `CogFailedError`, `CogStoppedError`, `CogNotYetRunError` | `Cog::Output` |
| `cog_type?(:name)` (query) | No | Returns `false` for any access error except `CogDoesNotExistError` | `bool` |

The strict accessor (`!`) performs a **blocking wait** on async cogs before checking state. This is what makes sync cogs act as implicit barriers — any `!` access to a still-running async cog pauses the current fiber until that cog completes.

### State Check Order in `cog_output!`

**Source**: `lib/roast/cog_input_manager.rb:69–79`

```ruby
def cog_output!(cog_name)
  raise CogDoesNotExistError, cog_name unless @cogs.key?(cog_name)

  @cogs[cog_name].tap do |cog|
    cog.wait                                    # block until complete
    raise CogSkippedError, cog_name if cog.skipped?
    raise CogFailedError, cog_name if cog.failed?
    raise CogStoppedError, cog_name if cog.stopped?
    raise CogNotYetRunError, cog_name unless cog.succeeded?
  end.output.deep_dup                           # defensive copy on every access
end
```

The check order matters: `skipped?` → `failed?` → `stopped?` → `succeeded?`. A cog that was both `@skipped = true` and has a failed task will report as skipped (because `skipped?` is checked first).

**Deep copy**: Every successful output access returns a `deep_dup` of the output object (line 78). This prevents the caller from mutating the original output, maintaining the framework's isolation guarantees.

---

## 6. The `outputs` / `outputs!` Finalizer

**Source**: `lib/roast/execution_manager.rb:254–283`

The `compute_final_output` method runs in the `ensure` block of `ExecutionManager.run!` (line 112), guaranteeing it always executes. It is also called eagerly at line 109 (normal completion) and line 155 (before re-raising `Break`). The `@final_output_computed` flag (line 256) ensures idempotency.

### Error Handling Matrix

| Error Type | `outputs { ... }` (tolerant) | `outputs! { ... }` (strict) |
|------------|------------------------------|-----------------------------|
| `CogNotYetRunError` | Swallowed → `final_output = nil` | **Re-raised** |
| `CogSkippedError` | Swallowed → `final_output = nil` | **Re-raised** |
| `CogStoppedError` | Swallowed → `final_output = nil` | **Re-raised** |
| `CogDoesNotExistError` | **Not caught** → propagates | **Not caught** → propagates |
| `CogFailedError` | **Not caught** → propagates | **Not caught** → propagates |
| `ControlFlow::SkipCog` | Swallowed → `final_output = nil` | Swallowed → `final_output = nil` |
| `ControlFlow::Next` | Swallowed → `final_output = nil` | Swallowed → `final_output = nil` |
| `ControlFlow::FailCog` | **Not caught** → propagates | **Not caught** → propagates |
| `ControlFlow::Break` | **Not caught** → propagates | **Not caught** → propagates |

**Source for rescue clauses**: lines 268–282.

### Default Behavior (No `outputs` Block)

If neither `outputs` nor `outputs!` is defined, `compute_final_output` falls back to:

```ruby
last_cog_name = @cog_stack.last&.name
raise CogDoesNotExistError, "no cogs defined in scope" unless last_cog_name
@cog_input_manager.send(:cog_output, last_cog_name)
```

This uses the **tolerant** accessor on the last cog in the stack. If the last cog was skipped, failed, or stopped, `final_output` will be `nil` (not an exception).

---

## 7. Known Bugs and Edge Cases

### Bug 1: Repeat + Sync `next!` Escapes the Loop

**Location**: `lib/roast/system_cogs/repeat.rb:216–233`

**Problem**: `Repeat::Manager` only catches `ControlFlow::Break`. If a **synchronous** cog inside a repeat loop calls `next!`, the inner `ExecutionManager.run!` propagates the `Next` exception (Layer 2 sync path), and Repeat has no rescue for it. The exception escapes the entire repeat cog and propagates to the parent scope.

**Expected behavior**: `next!` should advance to the next iteration (like it does for async cogs, where the inner EM swallows it).

**Workaround**: Use `break!` to exit, or make the cog async.

### Bug 2: Top-Level Sync `next!` Is Unhandled

**Location**: `lib/roast/workflow.rb:61–73`

**Problem**: `Workflow.start!` only catches `ControlFlow::Break`. A synchronous cog at the top level calling `next!` produces an unhandled `ControlFlow::Next` exception.

**Expected behavior**: `next!` at the top level should terminate the workflow gracefully (like `break!` does).

**Workaround**: Use `break!` instead of `next!` at the top level.

### Bug 3: `outputs!` + `break!` Exception Masking

**Location**: `lib/roast/execution_manager.rb:110–112, 254–282`

**Problem**: When `break!` terminates a scope, `compute_final_output` runs in the `ensure` block. If the `outputs!` block accesses a cog that was skipped due to `break!`, `CogSkippedError` is raised. In Ruby, an exception raised in `ensure` **replaces** the original exception (`ControlFlow::Break`). The parent scope sees `CogSkippedError` instead of `Break`, which may prevent proper loop termination.

**Expected behavior**: The `Break` exception should propagate to the parent for loop control, regardless of what happens in `outputs!`.

**Workaround**: Use `outputs` (tolerant) instead of `outputs!` when `break!` may be called.

### Bug 4: Empty Scope Without `outputs` Block

**Location**: `lib/roast/execution_manager.rb:263–264`

**Problem**: If a scope has zero cogs and no `outputs` block, `@cog_stack.last` is `nil`, and the code raises `CogDoesNotExistError` with "no cogs defined in scope". This error is **not** in the rescue clauses of `compute_final_output`, so it propagates.

**Expected behavior**: An empty scope should produce `nil` as `final_output`.

### Edge Case: `FailCog` in `outputs` Block

**Source**: `lib/roast/execution_manager.rb:268–282`

The rescue clauses in `compute_final_output` do **not** catch `ControlFlow::FailCog`. If the `outputs` block calls `fail!`, the exception propagates even from the tolerant `outputs` variant. This is intentional — calling `fail!` in a finalizer is a deliberate error signal that should not be silently swallowed.

### Edge Case: `Break` in `outputs` Block

`ControlFlow::Break` is also **not** caught by `compute_final_output`. Calling `break!` inside an `outputs` block propagates the break signal to the parent scope. This is by design — `break!` is meant to signal loop termination at any level.

---

## 8. Control Flow Transparency in Helpers

The three scope-bridging helpers — `from`, `collect`, and `reduce` — are **transparent** to control flow. They do not catch any `ControlFlow` exceptions. If a block passed to these helpers raises `skip!`, `fail!`, `next!`, or `break!`, that exception propagates directly to the calling context (typically an `outputs` block or a cog input block).

| Helper | Source | Block context |
|--------|--------|---------------|
| `from(call_output) { ... }` | `lib/roast/system_cogs/call.rb:147–157` | Block runs in the **called scope's** `CogInputContext` |
| `collect(map_output) { ... }` | `lib/roast/system_cogs/map.rb:375–389` | Block runs in **each iteration's** `CogInputContext` |
| `reduce(map_output, init) { ... }` | `lib/roast/system_cogs/map.rb:426–448` | Block runs in **each iteration's** `CogInputContext` |

**Practical consequence**: Calling `break!` inside a `collect` block in an `outputs` context will propagate `Break` out of `compute_final_output`, potentially masking the loop's normal termination.

---

## 9. Decision Tree for Workflow Authors

Use this to choose the right control flow primitive.

```
Want to skip JUST THIS COG?
  └── YES → skip!
       (cog becomes nil, workflow continues)

Want to signal THIS COG FAILED?
  └── YES → fail!
       ├── abort_on_failure? = true  → scope terminates (default)
       └── abort_on_failure? = false → cog becomes nil, workflow continues

Want to ADVANCE TO NEXT ITERATION?
  └── YES → next!
       ├── In map (serial or parallel) → ✅ works correctly
       ├── In repeat with ASYNC cogs  → ✅ works correctly
       ├── In repeat with SYNC cogs   → ⚠️ BUG: escapes repeat
       ├── In call scope              → ✅ ends scope early
       └── At top level with SYNC cog → ⚠️ BUG: unhandled

Want to EXIT THE LOOP ENTIRELY?
  └── YES → break!
       ├── In map     → ✅ stops all iterations
       ├── In repeat  → ✅ exits loop
       ├── In call    → ✅ ends scope early
       └── At top level → ✅ graceful workflow termination
```

### Safety Recommendations

1. **Prefer `break!` over `next!` for sync cogs in repeat loops.** The `next!` bug means sync cogs cannot reliably advance repeat iterations.
2. **Prefer `outputs` over `outputs!` when `break!` may be called.** The exception-masking interaction means strict mode can interfere with loop control.
3. **Never call `fail!` inside an `outputs` block** unless you intend to terminate the scope with an error. It propagates even from tolerant `outputs`.
4. **`CogDoesNotExistError` is always fatal.** Neither the tolerant accessor (`cog_type(:name)`) nor the tolerant finalizer (`outputs`) will catch it. Always ensure cog names are correct.

---

## 10. Quick-Reference: Exception × Layer Matrix

A compact summary for fast lookup.

| Exception | Cog.run! | EM sync | EM async handler | Call | Map serial | Map parallel | Repeat | Workflow.start! |
|-----------|----------|---------|------------------|------|------------|--------------|--------|-----------------|
| `SkipCog` | swallow | — | — | — | — | — | — | — |
| `FailCog` (abort=false) | swallow | — | — | — | — | — | — | — |
| `FailCog` (abort=true) | re-raise | propagate | re-raise | propagate | propagate | barrier stop, re-raise | propagate | **unhandled** |
| `Next` | re-raise | propagate | **swallow** | catch | catch (advance) | catch per-task | **⚠️ escapes** | **⚠️ unhandled** |
| `Break` | re-raise | propagate | re-raise | catch | catch (exit loop) | barrier stop | catch (exit loop) | catch (graceful) |
| `StandardError` | re-raise | propagate | re-raise | propagate | propagate | barrier stop, re-raise | propagate | propagate |

**Legend**: "—" means the exception never reaches this layer. "swallow" means caught and not re-raised. "propagate" means exception passes through without being caught. "catch" means caught and handled appropriately.
