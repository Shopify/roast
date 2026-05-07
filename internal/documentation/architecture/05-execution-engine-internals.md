# Document 5: Execution Engine Internals

_Deep reference for how the three managers orchestrate the full Roast lifecycle._

**Primary audience**: AI coding agents (critical for navigating code), Intern (after completing the learning path)

---

## Overview

The execution engine is a triad of collaborating managers:

| Manager | Source | Context owned | Responsibility |
|---------|--------|---------------|----------------|
| `ConfigManager` | `lib/roast/config_manager.rb` | `ConfigContext` | Evaluate `config {}` blocks, assemble merged configs |
| `ExecutionManager` | `lib/roast/execution_manager.rb` | `ExecutionContext` | Evaluate `execute {}` blocks, run cog stack, manage async |
| `CogInputManager` | `lib/roast/cog_input_manager.rb` | `CogInputContext` | Provide runtime data access (output, params, control flow) |

Each manager owns one blank context class and dynamically installs methods on it via `define_singleton_method`. The context instances are the surfaces where user-written DSL blocks are evaluated via `instance_eval` or `instance_exec`.

---

## 1. ExecutionManager

**File**: `lib/roast/execution_manager.rb`

### 1.1 Class Structure

```
ExecutionManager
  include SystemCogs::Call::Manager
  include SystemCogs::Map::Manager
  include SystemCogs::Repeat::Manager
```

The three system cog Manager modules are mixed in so they can access EM internals (`@cog_registry`, `@config_manager`, `@all_execution_procs`, `@workflow_context`) when creating child EMs. This is **intentionally not polymorphic** — system cog execution needs EM encapsulation, and making it polymorphic would leak those internals through a public interface.

### 1.2 Constructor (lines 51–74)

```ruby
def initialize(
  cog_registry,        # Cog::Registry — the 7 registered cog types
  config_manager,      # ConfigManager — shared across all EMs in a workflow
  all_execution_procs, # Hash[Symbol?, Array[Proc]] — ALL scopes, flat namespace
  workflow_context,     # WorkflowContext — params, tmpdir, workflow_dir
  scope: nil,          # Symbol? — which scope's procs to evaluate
  scope_value: nil,    # untyped — passed to cogs as scope_value
  scope_index: 0       # Integer — iteration counter (for map/repeat)
)
```

Creates fresh instances of:
- `Cog::Store` — name→cog mapping (uniqueness enforced)
- `Cog::Stack` — ordered execution queue (FIFO via `shift`)
- `ExecutionContext` — blank target for DSL method installation
- `CogInputManager` — immediately binds accessors on its `CogInputContext`
- `Async::Barrier` — task group for cooperative scheduling

Also initializes:
- `@final_output = nil` — computed once, then frozen via flag
- `@final_output_computed = false` — idempotency guard

**Key design point**: `@all_execution_procs` is the *same Hash reference* across every child EM in the workflow. Scopes are globally addressable — a scope defined at the workflow level is callable from any depth. The `scope:` parameter simply selects which key's procs to evaluate.

### 1.3 prepare! (lines 77–85)

```ruby
def prepare!
  raise ExecutionManagerAlreadyPreparedError if preparing? || prepared?
  @preparing = true
  bind_outputs                    # install `outputs` and `outputs!` DSL methods
  bind_registered_cogs            # install cog type methods (agent, cmd, etc.)
  my_execution_procs.each { |ep| @execution_context.instance_eval(&ep) }
  @prepared = true
end
```

**Step by step**:

1. **Guard**: Double-prepare raises immediately. Uses both `preparing?` and `prepared?` flags.
2. **`bind_outputs`** (lines 228–237): Installs `outputs` and `outputs!` as singleton methods on `@execution_context`. Both capture `method(:on_outputs)` / `method(:on_outputs!)` closures and delegate to them.
3. **`bind_registered_cogs`** (lines 182–183): Iterates `@cog_registry.cogs` (all 7 entries) and calls `bind_cog` for each.
4. **Evaluate execution procs**: The user's `execute {}` blocks run against the context. This is when all cog declarations actually execute — calling `agent(:name) { ... }` routes to `on_execute`, which creates cog instances and pushes them onto the stack.

**`my_execution_procs`** (lines 163–167): Validates that `@all_execution_procs` has a key matching `@scope`. If not, raises `ExecutionScopeDoesNotExistError`. Returns the array of procs (or `[]` if the key exists but is nil).

### 1.4 bind_cog (lines 187–197)

```ruby
def bind_cog(cog_method_name, cog_class)
  on_execute_method = method(:on_execute)
  cog_method = proc do |*args, **kwargs, &cog_input_proc|
    on_execute_method.call(cog_class, args, kwargs, cog_input_proc)
  end
  @execution_context.instance_eval do
    raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)
    define_singleton_method(cog_method_name, cog_method)
  end
end
```

**Pattern**: Captures a reference to `on_execute` via `method(:on_execute)`. Creates a proc that closes over both `cog_class` and the method reference. Installs it on the context via `define_singleton_method`.

**Name conflict check**: `respond_to?(cog_method_name, true)` — the `true` includes private methods. A cog named `:freeze` would conflict with `Object#freeze`. Checked at prepare-time for early error surfacing.

### 1.5 on_execute (lines 200–226) — The Dispatch Hub

```ruby
def on_execute(cog_class, cog_args, cog_kwargs, cog_input_proc)
  if cog_class <= SystemCog
    cog_params = cog_class.params_class.new(*cog_args, **cog_kwargs)
    cog_instance = if cog_class == SystemCogs::Call
      create_call_system_cog(cog_params, cog_input_proc)
    elsif cog_class == SystemCogs::Map
      create_map_system_cog(cog_params, cog_input_proc)
    elsif cog_class == SystemCogs::Repeat
      create_repeat_system_cog(cog_params, cog_input_proc)
    else
      raise NotImplementedError, "No system cog manager defined for #{cog_class}"
    end
  else
    cog_name = Array.wrap(cog_args).shift
    if cog_name
      anonymous = false
    else
      anonymous = true
      cog_name = Cog.generate_fallback_name  # Random.uuid.to_sym
    end
    cog_instance = cog_class.new(cog_name, cog_input_proc, anonymous:)
  end
  add_cog_instance(cog_instance)
end
```

**System cogs**: First constructs a `Params` object from the args/kwargs, then delegates to the appropriate Manager module method (e.g., `create_call_system_cog`). The Manager methods are defined in `SystemCogs::Call::Manager`, etc., which are `include`d at the top of `ExecutionManager`.

**Standard cogs**: Extracts the name from the first positional arg. If no name is provided, generates a UUID-based anonymous name. Anonymous cogs exist in the Store but cannot be meaningfully referenced by users.

**`add_cog_instance`** (lines 170–173): Inserts into both `@cogs` (Store — for lookup) and `@cog_stack` (Stack — for execution order). Store raises `CogAlreadyDefinedError` on duplicate names.

### 1.6 run! (lines 87–116) — The Main Loop

```ruby
def run!
  raise ExecutionManagerNotPreparedError unless prepared?
  raise ExecutionManagerCurrentlyRunningError if running?

  @running = true
  Sync do |sync_task|
    sync_task.annotate("ExecutionManager #{@scope}")
    TaskContext.begin_execution_manager(self)
    @cog_stack.each do |cog|
      cog_config = @config_manager.config_for(cog.class, cog.name)
      cog_task = cog.run!(
        @barrier,
        cog_config.deep_dup,
        cog_input_context,
        @scope_value.deep_dup,
        @scope_index,
      )
      cog_task.wait unless cog_config.async?
    end
    @barrier.wait { |task| wait_for_task_with_exception_handling(task) }
    compute_final_output
  ensure
    @barrier.stop
    compute_final_output
    TaskContext.end
    @running = false
  end
end
```

**Detailed execution trace**:

1. **Guards**: Must be prepared. Cannot re-enter.
2. **Sync**: Enters an Async event loop (or reuses the current fiber scheduler).
3. **TaskContext annotation**: Registers this EM in the fiber-local execution path for debugging/eventing.
4. **Iterate cog stack**: For each cog:
   - a. **Resolve config**: `config_for(cog.class, cog.name)` runs the full 5-step merge cascade (see §2.3).
   - b. **Deep dup config**: `cog_config.deep_dup` — prevents config mutation by one cog from leaking to the next.
   - c. **Deep dup scope_value**: `@scope_value.deep_dup` — prevents scope value mutation by one cog from affecting subsequent cogs.
   - d. **Launch cog**: `cog.run!` creates an async task on the barrier. Returns the `Async::Task` handle.
   - e. **Wait if sync**: `cog_task.wait unless cog_config.async?` — blocks the fiber until the cog completes. This is what makes sync cogs sequential.
5. **Barrier wait**: After the loop, waits on remaining async tasks in completion order. Each task is processed through `wait_for_task_with_exception_handling`.
6. **Eager compute**: `compute_final_output` is called immediately so its result is available for chaining (e.g., in repeat loops).
7. **Ensure block**: Always runs:
   - `@barrier.stop` — kills any still-running tasks (e.g., after Break)
   - `compute_final_output` — idempotent second call ensures output is always computed
   - `TaskContext.end` — pops the fiber-local path element
   - `@running = false` — resets state

### 1.7 Deep Dup Boundaries in run!

Two explicit `deep_dup` calls on lines 99 and 101:

| Site | What's copied | Why |
|------|---------------|-----|
| `cog_config.deep_dup` | The merged config object | Cog N modifying its config mustn't affect Cog N+1 |
| `@scope_value.deep_dup` | The current scope value | Cog N modifying the scope value mustn't affect Cog N+1 |

Both are per-cog copies — called once for each cog in the stack.

### 1.8 wait_for_task_with_exception_handling (lines 148–160)

```ruby
def wait_for_task_with_exception_handling(task)
  task.wait
rescue ControlFlow::Next
  @barrier.stop
rescue ControlFlow::Break => e
  @barrier.stop
  compute_final_output
  raise e
rescue StandardError => e
  @barrier.stop
  raise e
end
```

This is the **critical async exception handler**. It processes tasks that complete during `@barrier.wait`:

| Exception | Behavior | Propagates? |
|-----------|----------|-------------|
| `ControlFlow::Next` | Stops barrier (kills remaining tasks) | **NO** — swallowed |
| `ControlFlow::Break` | Stops barrier, computes output | **YES** — re-raised |
| `StandardError` | Stops barrier | **YES** — re-raised |

**⚠️ CRITICAL BEHAVIORAL DIFFERENCE**: This handler only processes tasks that were *async* (not already awaited via `cog_task.wait`). For sync cogs, exceptions propagate directly from `cog_task.wait` (line 104), exiting the `each` loop immediately. This means:

- **Sync `next!`**: Propagates out of `run!` to the parent scope (Map/Repeat manager catches it)
- **Async `next!`**: Swallowed here — parent scope never knows

- **Sync `break!`**: Propagates out of `run!` (via `cog_task.wait`)
- **Async `break!`**: Also propagates — re-raised after stopping barrier

### 1.9 compute_final_output (lines 254–283)

```ruby
def compute_final_output
  return if @final_output_computed
  @final_output_computed = true
  outputs_proc = @outputs_bang || @outputs

  @final_output = if outputs_proc
    @cog_input_manager.context.instance_exec(@scope_value, @scope_index, &outputs_proc)
  else
    last_cog_name = @cog_stack.last&.name
    raise CogInputManager::CogDoesNotExistError, "no cogs defined in scope" unless last_cog_name
    @cog_input_manager.send(:cog_output, last_cog_name)
  end
rescue ControlFlow::SkipCog, ControlFlow::Next
  # Swallowed — final_output becomes nil
rescue CogInputManager::CogNotYetRunError, CogInputManager::CogSkippedError, CogInputManager::CogStoppedError => e
  raise e if @outputs_bang.present?
  # Swallowed for `outputs` (tolerant) — final_output becomes nil
end
```

**Idempotent**: The `@final_output_computed` flag prevents re-computation. Called both eagerly (line 109) and in `ensure` (line 112).

**Priority**:
1. If `outputs_proc` exists (from `outputs {}` or `outputs! {}`): evaluate it in `CogInputContext`, passing scope_value and scope_index.
2. If NO outputs proc: fall back to the last cog's output via `cog_output(last_cog_name)`.

**`outputs` vs `outputs!`** (mutually exclusive — `OutputsAlreadyDefinedError` if both set):
- `outputs`: Tolerant. `CogNotYetRunError`, `CogSkippedError`, `CogStoppedError` are swallowed → `nil`.
- `outputs!`: Strict. Same exceptions re-raised to the caller.

Both variants swallow `SkipCog` and `Next` — these are valid ways to "produce no output" from an outputs block.

**Linchpin for Repeat**: `em.final_output` is what feeds `scope_value` for the next iteration of a repeat loop. The idempotent computation ensures it's always available even after Break.

### 1.10 bind_outputs (lines 228–251)

```ruby
def bind_outputs
  on_outputs_method = method(:on_outputs)
  on_outputs_bang_method = method(:on_outputs!)
  method_to_bind = proc { |&outputs_proc| on_outputs_method.call(outputs_proc) }
  bang_method_to_bind = proc { |&outputs_proc| on_outputs_bang_method.call(outputs_proc) }
  @execution_context.instance_eval do
    define_singleton_method(:outputs, method_to_bind)
    define_singleton_method(:outputs!, bang_method_to_bind)
  end
end
```

Both `on_outputs` (line 240) and `on_outputs!` (line 247) raise `OutputsAlreadyDefinedError` if either `@outputs` or `@outputs_bang` is already set. Only one outputs declaration per scope.

### 1.11 Error Hierarchy

```
Roast::Error
  ExecutionManagerError
    ExecutionManagerNotPreparedError
    ExecutionManagerAlreadyPreparedError
    ExecutionManagerCurrentlyRunningError
    ExecutionScopeDoesNotExistError
    ExecutionScopeNotSpecifiedError
    IllegalCogNameError
    OutputsAlreadyDefinedError
```

---

## 2. ConfigManager

**File**: `lib/roast/config_manager.rb`

### 2.1 Internal Storage

```ruby
@global_config         = Cog::Config.new           # target of `global {}` blocks
@general_configs       = {}                        # Hash[singleton(Cog), Cog::Config]
@regexp_scoped_configs = {}                        # Hash[singleton(Cog), Hash[Regexp, Cog::Config]]
@name_scoped_configs   = {}                        # Hash[singleton(Cog), Hash[Symbol, Cog::Config]]
```

Four levels of configuration storage, one per cascade tier. Each maps a cog *class* (not instance) to a config object. This means config is resolved per-class-and-name, not per-instance.

### 2.2 prepare! (lines 23–31)

```ruby
def prepare!
  raise ConfigManagerAlreadyPreparedError if preparing? || prepared?
  @preparing = true
  bind_global           # install `global {}` DSL method
  bind_registered_cogs  # install per-cog config methods
  @config_procs.each { |cp| @config_context.instance_eval(&cp) }
  @prepared = true
end
```

1. **`bind_global`** (lines 124–132): Installs `global` as a singleton method on `@config_context`. The global block runs against `@global_config` via `instance_exec`.
2. **`bind_registered_cogs`** (lines 81–82): For each registered cog type, installs a method with the same name on `@config_context`.
3. **Evaluate config procs**: All `config {}` blocks from the workflow are evaluated sequentially. Multiple config blocks accumulate — they don't replace each other.

### 2.3 config_for (lines 44–59) — THE MERGE CASCADE

This is the method called by `ExecutionManager.run!` before each cog runs:

```ruby
def config_for(cog_class, name = nil)
  raise ConfigManagerNotPreparedError unless prepared?

  # Step 1: Global seed — cog-specific config seeded with global values
  config = cog_class.config_class.new(@global_config.instance_variable_get(:@values).deep_dup)

  # Step 2: General merge — type-wide defaults
  config = config.merge(fetch_general_config(cog_class))

  # Step 3: Regexp merge — pattern-matched overrides
  @regexp_scoped_configs.fetch(cog_class, {}).select do |pattern, _|
    pattern.match?(name.to_s) unless name.nil?
  end.values.each { |cfg| config = config.merge(cfg) }

  # Step 4: Name merge — cog-specific overrides
  unless name.nil?
    name_scoped_config = fetch_name_scoped_config(cog_class, name)
    config = config.merge(name_scoped_config)
  end

  # Step 5: Validate
  config.validate!
  config
end
```

**Step 1 — The Global Config Back-Door**: Uses `instance_variable_get(:@values)` to extract the raw values hash from `@global_config`. This is the *only* place in the codebase that reaches into `@values` from outside `Cog::Config`. Why? Because global config is a base `Cog::Config`, not a cog-specific Config. It may contain keys (like `model` or `temperature`) that only make sense for specific cog types. The cog-specific `config_class.new(values)` accepts them into its own `@values` hash via its constructor. The `deep_dup` prevents mutation of the shared global config.

**Steps 2–4**: Each `fetch_*` method lazily creates an empty config if none exists (`||=`). This means `config_for` always returns a valid config even for unconfigured cogs. The `merge` method on `Config` does a non-destructive merge: only keys present in the source overwrite keys in the target.

**Step 5**: Calls `validate!` on the assembled config. Each cog-specific Config class can override `validate!` to enforce constraints (e.g., Map validates that `parallel` is non-negative).

**Regexp matching note**: All matching patterns are applied in insertion order. If multiple patterns match, their configs are merged sequentially (last wins for any given key).

### 2.4 on_config (lines 98–122) — Config Dispatch

```ruby
def on_config(cog_class, cog_name_or_pattern, cog_config_proc)
  config_object = case cog_name_or_pattern
  when NilClass  → fetch_general_config(cog_class)
  when Regexp    → fetch_regexp_scoped_config(cog_class, pattern)
  when Symbol    → fetch_name_scoped_config(cog_class, name)
  else           → raise ArgumentError
  end
  config_object.instance_exec(&cog_config_proc) if cog_config_proc
end
```

The proc runs in the context of the Config object itself. This is why calling `model("gpt-4o")` inside a config block works — it invokes the `model` setter on the Config instance.

### 2.5 bind_cog (lines 86–96)

```ruby
def bind_cog(cog_method_name, cog_class)
  on_config_method = method(:on_config)
  cog_method = proc do |cog_name_or_pattern = nil, &cog_config_proc|
    on_config_method.call(cog_class, cog_name_or_pattern, cog_config_proc)
  end
  @config_context.instance_eval do
    raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)
    define_singleton_method(cog_method_name, cog_method)
  end
end
```

Same metaprogramming pattern as EM's `bind_cog`: capture method reference in closure, define on context.

### 2.6 Error Hierarchy

```
Roast::Error
  ConfigManagerError
    ConfigManagerNotPreparedError
    ConfigManagerAlreadyPreparedError
    IllegalCogNameError
```

---

## 3. ExecutionManager ↔ ConfigManager Interaction

The EM and CM have a **one-directional dependency**: EM calls CM, CM never calls EM.

```
Workflow.prepare!
  → ConfigManager.prepare!   (evaluates config blocks first)
  → ExecutionManager.prepare! (evaluates execute blocks second)

ExecutionManager.run!
  → per cog: @config_manager.config_for(cog.class, cog.name)
  → config.deep_dup  (isolation before passing to cog)
  → cog.run!(..., config, ...)
```

**Critical sequencing**: CM must be prepared before EM's execution procs run. The execution procs declare cogs; the config for those cogs must already be collected. However, `config_for` is lazy — it doesn't need the EM's cog list at all. It computes the merged config on-demand from the storage hashes that were populated during CM's `prepare!`.

**Shared across child EMs**: All child EMs (created by Call, Map, Repeat managers) share the same `@config_manager` instance. Config is workflow-wide.

---

## 4. CogInputManager

**File**: `lib/roast/cog_input_manager.rb`

### 4.1 Constructor (lines 19–27)

```ruby
def initialize(cog_registry, cogs, workflow_context)
  @cog_registry = cog_registry
  @cogs = cogs                    # Cog::Store — THIS EM's cogs only
  @workflow_context = workflow_context
  @context = CogInputContext.new
  bind_registered_cogs            # immediately installs output accessors
  bind_workflow_context           # immediately installs target!, kwargs, etc.
end
```

Unlike EM and CM, CIM does **not** have a `prepare!` phase. It binds everything in the constructor because cog input blocks can reference any cog in the same scope at any time.

**Important**: `@cogs` is the Store from *this* EM only. A cog in scope A cannot directly access a cog in scope B through the input context. Cross-scope access requires `from()`.

### 4.2 The Three Output Accessors

For each registered cog type (e.g., `:agent`), three methods are installed on `CogInputContext` (lines 40–51):

| Installed method | Maps to | Behavior |
|-----------------|---------|----------|
| `agent(:name)` | `cog_output(name)` | Tolerant — returns nil on error |
| `agent?(:name)` | `cog_output?(name)` | Boolean — `!cog_output(name).nil?` |
| `agent!(:name)` | `cog_output!(name)` | Strict — raises on error |

#### `cog_output!` (lines 69–79) — The Strict Path

```ruby
def cog_output!(cog_name)
  raise CogDoesNotExistError, cog_name unless @cogs.key?(cog_name)

  @cogs[cog_name].tap do |cog|
    cog.wait                                    # blocks if async task still running
    raise CogSkippedError, cog_name if cog.skipped?
    raise CogFailedError, cog_name if cog.failed?
    raise CogStoppedError, cog_name if cog.stopped?
    raise CogNotYetRunError, cog_name unless cog.succeeded?
  end.output.deep_dup                           # ALWAYS deep copies output
end
```

**Blocking behavior**: `cog.wait` calls `@task&.wait` on the cog's Async task. If the cog is async and still running, this fiber yields until completion. This is how output access "implicitly awaits" async cogs.

**State check order**: skipped → failed → stopped → not-yet-run. All four states are checked before output access.

**Deep dup on access**: `output.deep_dup` ensures each accessor call returns an independent copy. Mutating the returned output never affects the source cog's stored output.

#### `cog_output` (lines 54–61) — The Tolerant Path

```ruby
def cog_output(cog_name)
  cog_output!(cog_name)
rescue CogOutputAccessError => e
  raise e if e.is_a?(CogDoesNotExistError)
  nil
end
```

Delegates to `cog_output!` but rescues all `CogOutputAccessError` **except** `CogDoesNotExistError`. Design rationale: accessing a nonexistent cog is likely a typo (always an error), but accessing a cog that didn't produce output (skipped, failed, stopped, not yet run) is forgivable.

#### `cog_output?` (lines 64–66) — The Boolean Path

```ruby
def cog_output?(cog_name)
  !cog_output(cog_name).nil?
end
```

Simply checks if the tolerant path returns non-nil.

### 4.3 Workflow Context Accessors (lines 82–105)

All bound via `define_singleton_method` on the `CogInputContext`:

| Method | Implementation | Return type |
|--------|---------------|-------------|
| `target!` | Raises if not exactly 1 target; returns first | `String` |
| `targets` | `@workflow_context.params.targets.dup` | `Array[String]` |
| `arg?(value)` | `params.args.include?(value)` | `bool` |
| `args` | `params.args.dup` | `Array[Symbol]` |
| `kwarg(key)` | `params.kwargs[key]` | `String?` |
| `kwarg!(key)` | Raises if key missing | `String` |
| `kwarg?(key)` | `params.kwargs.include?(key)` | `bool` |
| `kwargs` | `params.kwargs.dup` | `Hash[Symbol, String]` |
| `tmpdir` | `Pathname.new(...).realpath` | `Pathname` |
| `template(path, args)` | 13-candidate resolution + ERB | `String` |

**Defensive copying**: `targets`, `args`, `kwargs` all return `.dup`. Lighter than `deep_dup` because their contents are simple values (strings, symbols).

### 4.4 Template Resolution (lines 182–223) — 13-Candidate Priority Stack

Given `template("greeting", name: "World")`:

```
1.  Absolute path as-is                        (if path.absolute?)
2.  workflow_dir / path
3.  workflow_dir / "#{path}.erb"
4.  workflow_dir / "#{path}.md.erb"
5.  workflow_dir / "prompts" / path
6.  workflow_dir / "prompts" / "#{path}.erb"
7.  workflow_dir / "prompts" / "#{path}.md.erb"
8.  pwd / path
9.  pwd / "#{path}.erb"
10. pwd / "#{path}.md.erb"
11. pwd / "prompts" / path
12. pwd / "prompts" / "#{path}.erb"
13. pwd / "prompts" / "#{path}.md.erb"
```

Uses `candidate_paths.find(&:exist?)` — first match wins. Renders with `ERB.new(resolved_path.read).result_with_hash(args)`.

Raises `CogInputContext::ContextNotFoundError` if no candidate exists.

**Known bug**: `Pathname` does NOT expand `~` for home directory. Tracked as [issue #663](https://github.com/Shopify/roast/issues/663).

### 4.5 Error Hierarchy

```
Roast::Error
  CogOutputAccessError            ← NOTE: under Roast::Error, NOT under CogError
    CogDoesNotExistError
    CogNotYetRunError
    CogSkippedError
    CogFailedError
    CogStoppedError
  CogInputContext::ContextNotFoundError  ← raised by template() and from()
```

**Intentional separation**: `CogOutputAccessError` is a *consumer-side* error (raised when accessing another cog's output). `CogError` is a *producer-side* error (raised within a cog's own lifecycle). They're separate hierarchies under `Roast::Error` because they serve different error handling audiences.

---

## 5. Cog.run! Lifecycle (Detailed)

**File**: `lib/roast/cog.rb`, lines 71–101

### 5.1 Method Signature

```ruby
def run!(barrier, config, input_context, executor_scope_value, executor_scope_index)
```

Receives:
- `barrier` — the EM's `Async::Barrier` for task registration
- `config` — already deep_dup'd by EM
- `input_context` — the `CogInputContext` with all accessors bound
- `executor_scope_value` — already deep_dup'd by EM
- `executor_scope_index` — the iteration index

### 5.2 Execution Trace

```ruby
@task = barrier.async(finished: false) do |task|
  task.annotate("Cog #{type}(:#{@name})")
  TaskContext.begin_cog(self)
  @config = config
  input_instance = self.class.input_class.new
  input_return = input_context.instance_exec(
    input_instance, executor_scope_value, executor_scope_index, &@cog_input_proc
  ) if @cog_input_proc
  coerce_and_validate_input!(input_instance, input_return)
  @output = execute(input_instance)
rescue ControlFlow::SkipCog
  @skipped = true
rescue ControlFlow::FailCog => e
  @failed = true
  raise e if config.abort_on_failure?
rescue ControlFlow::Next, ControlFlow::Break => e
  @skipped = true
  raise e
rescue StandardError => e
  @failed = true
  raise e
ensure
  TaskContext.end
end
```

**Step by step**:

1. **barrier.async(finished: false)**: Creates an async task on the barrier. `finished: false` means the barrier won't consider this task done until it explicitly completes — required for proper barrier cleanup.
2. **TaskContext annotation**: Registers the cog in the fiber-local path for debugging.
3. **Config assignment**: `@config = config` — makes the merged config available to `execute`.
4. **Input creation**: `self.class.input_class.new` — creates a fresh Input instance.
5. **Input block evaluation**: `instance_exec` on the CogInputContext with three args: the input instance, scope_value, and scope_index. The `&@cog_input_proc` is the user's `{ |my, scope_value, index| ... }` block.
6. **Coerce and validate**: `coerce_and_validate_input!(input_instance, input_return)` — the two-phase validation.
7. **Execute**: Calls the cog-specific `execute(input_instance)` method, which returns an Output.

### 5.3 Two-Phase Input Validation (lines 149–157)

```ruby
def coerce_and_validate_input!(input, return_value)
  input.validate!                        # Phase 1: optimistic — is input already valid?
rescue Cog::Input::InvalidInputError
  input.coerce(return_value)             # If not, try coercion from return value
  input.validate!                        # Phase 2: mandatory — must be valid now
end
```

**Design**: Allows users to either set input fields explicitly (`my.prompt = "..."`) or rely on implicit coercion from the block's return value. The two-phase approach means explicit setting is checked first (fast path), coercion is only attempted if needed.

### 5.4 Exception Handling Matrix

| Exception | `@skipped` | `@failed` | Propagates? | Condition |
|-----------|-----------|----------|------------|-----------|
| `ControlFlow::SkipCog` | `true` | – | No | Always swallowed |
| `ControlFlow::FailCog` | – | `true` | Conditional | Only if `config.abort_on_failure?` (default: `true`) |
| `ControlFlow::Next` | `true` | – | Yes | Always re-raised |
| `ControlFlow::Break` | `true` | – | Yes | Always re-raised |
| `StandardError` | – | `true` | Yes | Always re-raised |

### 5.5 State Queries

| Method | Implementation | Notes |
|--------|---------------|-------|
| `started?` | `@task.present?` | True once `run!` is called |
| `skipped?` | `@skipped` | Set by SkipCog, Next, Break |
| `failed?` | `@failed \|\| !!@task&.failed?` | Explicit flag OR Async task failure |
| `stopped?` | `!!@task&.stopped?` | Async task was externally killed (barrier.stop) |
| `succeeded?` | `@output != nil && @task&.finished?` | The `!= nil` check is intentional — see below |

**The `succeeded?` gotcha**: Uses `@output != nil` (explicit nil check, not `.present?`) because the Ruby cog's Output class delegates `method_missing` to its `.value`. If the value is `nil`, `.present?` would return `false` even though the Output *object* exists. The `!= nil` check tests the object reference itself.

### 5.6 The `wait` Bare Rescue (lines 105–109)

```ruby
def wait
  @task&.wait
rescue
  # Do nothing
end
```

Used by `CogInputManager#cog_output!` to ensure a cog's task is complete before accessing its output. The bare rescue swallows *all* exceptions (including Next, Break). This is safe because:
1. Exceptions from the cog's task have already been propagated through the barrier system.
2. The purpose of `wait` here is only to ensure completion, not to handle errors.
3. The actual error checking happens via the state queries (`skipped?`, `failed?`, etc.) in `cog_output!`.

---

## 6. Registry, Store, Stack

### 6.1 Cog::Registry (`lib/roast/cog/registry.rb`)

```ruby
class Registry
  def initialize
    @cogs = {}
    use(SystemCogs::Call)
    use(SystemCogs::Map)
    use(SystemCogs::Repeat)
    use(Cogs::Cmd)
    use(Cogs::Chat)
    use(Cogs::Agent)
    use(Cogs::Ruby)
  end

  def use(cog_class)
    name, klass = create_registration(cog_class)
    cogs[name] = klass
  end

  private

  def create_registration(cog_class)
    cog_class_name = cog_class.name
    raise CouldNotDeriveCogNameError if cog_class_name.nil?
    [cog_class_name.demodulize.underscore.to_sym, cog_class]
  end
end
```

**Auto-registration**: All 7 built-in cogs are registered at construction time. Registration derives the method name from the class name: `Roast::Cogs::Agent` → `:agent`, `Roast::SystemCogs::Map` → `:map`.

**Custom cogs**: Use `registry.use(MyCustomCog)` to add new cog types. The custom cog's class name determines its DSL method name.

**One per workflow**: A single Registry instance is created by `Workflow` and shared across all managers.

### 6.2 Cog::Store (`lib/roast/cog/store.rb`)

```ruby
class Store
  delegate :[], :key?, to: :store

  def initialize
    @store = {}
  end

  def insert(cog)
    raise CogAlreadyDefinedError, cog.name if store.key?(cog.name)
    store[cog.name] = cog
  end
end
```

**Uniqueness constraint**: Cannot insert two cogs with the same name. This is per-EM, not global. Two different scopes can have cogs with the same name because they have separate EMs with separate Stores.

**Lookup**: `store[name]` for direct access, `store.key?(name)` for existence check.

### 6.3 Cog::Stack (`lib/roast/cog/stack.rb`)

```ruby
class Stack
  delegate :each, :empty?, :last, :map, :push, :size, to: :@queue

  def initialize
    @queue = []
  end

  def pop
    @queue.shift  # FIFO — pops from front
  end
end
```

**FIFO ordering**: Cogs execute in the order they were declared. `push` appends to the end, `pop` (shift) removes from the front.

**Note**: `run!` uses `each` (not `pop`) to iterate the stack. The `pop` method exists but is not used in the current execution path — it's for potential future use or external consumers.

**`last`**: Used by `compute_final_output` to determine which cog's output is the default final output when no `outputs` block is declared.

---

## 7. TaskContext — Fiber-Local Path Tracking

**File**: `lib/roast/task_context.rb`

```ruby
module TaskContext
  extend self

  class PathElement
    attr_reader :cog, :execution_manager
  end

  def path
    Fiber[:path]&.deep_dup || []
  end

  def begin_cog(cog)
    begin_element(PathElement.new(cog:))
  end

  def begin_execution_manager(execution_manager)
    begin_element(PathElement.new(execution_manager:))
  end

  def end
    Event << { end: Fiber[:path]&.last }
    el = Fiber[:path]&.pop
    [el, path]
  end

  private

  def begin_element(element)
    Fiber[:path] = (Fiber[:path] || []) + [element]
    Event << { begin: element }
    path
  end
end
```

**Fiber-local storage**: Uses `Fiber[:path]` (Ruby 3.2+ fiber storage) to maintain a per-fiber execution path. Each fiber has its own path — no cross-fiber contamination.

**Path structure**: Array of `PathElement` objects, alternating between EMs and Cogs. The path grows as execution descends into scopes and cogs, and shrinks as they complete.

**Event emission**: Both `begin_element` and `end` emit events via `Event <<`. This feeds the EventMonitor for logging and debugging.

**Deep dup on read**: `path` returns `deep_dup` to prevent external mutation of the fiber-local state.

---

## 8. WorkflowContext — Immutable Shared State

**File**: `lib/roast/workflow_context.rb`

```ruby
class WorkflowContext
  attr_reader :params      # WorkflowParams — targets, args, kwargs
  attr_reader :tmpdir      # String — Dir.mktmpdir path
  attr_reader :workflow_dir # Pathname — directory containing the workflow file

  def initialize(params:, tmpdir:, workflow_dir:)
    @params = params
    @tmpdir = tmpdir
    @workflow_dir = workflow_dir
  end
end
```

**Effectively immutable**: Created once during `Workflow.from_file`, shared across all managers and child EMs. Contains:
- `params` — parsed CLI arguments (targets, positional args, keyword args)
- `tmpdir` — a unique temporary directory created for this workflow run, cleaned up after
- `workflow_dir` — the directory of the workflow `.rb` file, used for template resolution

---

## 9. Complete Interaction Diagram

```
Workflow.from_file
  │
  ├─ creates WorkflowContext (params, tmpdir, workflow_dir)
  ├─ creates Cog::Registry (7 built-in cogs)
  ├─ creates ConfigManager (registry, config_procs)
  ├─ creates ExecutionManager (registry, CM, execution_procs, WC)
  │
  ├─ prepare!
  │   ├─ CM.prepare!
  │   │   ├─ bind_global → ConfigContext gets `global` method
  │   │   ├─ bind_registered_cogs → ConfigContext gets `agent`, `cmd`, ... methods
  │   │   └─ evaluate config procs → on_config fills @general/@regexp/@name_scoped_configs
  │   │
  │   └─ EM.prepare!
  │       ├─ bind_outputs → ExecutionContext gets `outputs`, `outputs!` methods
  │       ├─ bind_registered_cogs → ExecutionContext gets `agent`, `cmd`, ... methods
  │       └─ evaluate execution procs → on_execute creates Cog instances → Store + Stack
  │           └─ CogInputManager created in EM constructor
  │               ├─ bind_registered_cogs → CogInputContext gets `agent`/`agent!`/`agent?` triplets
  │               └─ bind_workflow_context → CogInputContext gets target!, kwargs, template, etc.
  │
  └─ start!
      └─ EM.run!
          └─ for each cog in stack:
              ├─ CM.config_for(cog.class, cog.name) → 5-step merge cascade
              ├─ config.deep_dup
              ├─ @scope_value.deep_dup
              └─ cog.run!(barrier, config, CogInputContext, scope_value, scope_index)
                  ├─ input_context.instance_exec(input, sv, si, &input_proc)
                  ├─ coerce_and_validate_input!
                  └─ execute(input) → Output
```

---

## 10. Invariants for Contributors

These invariants must be maintained when modifying the execution engine:

1. **Deep dup at every boundary**: If you create a new boundary where data crosses from one cog/scope to another, you MUST `deep_dup` at that boundary.

2. **Idempotent compute_final_output**: The flag pattern must be preserved. Calling it multiple times is safe and expected.

3. **Config is resolved per-cog-invocation, not cached**: `config_for` is called fresh for each cog in the stack. Don't cache configs across cogs.

4. **Execution procs are shared, not copied**: `@all_execution_procs` is the same Hash everywhere. Never mutate it after workflow construction.

5. **CIM binds immediately**: Unlike EM/CM, the CogInputManager binds all methods in its constructor. New accessor types must be bound there.

6. **Name conflict checks include private methods**: `respond_to?(name, true)` — don't forget the `true`.

7. **System cog dispatch is intentionally not polymorphic**: Adding a new system cog requires adding a new `elsif` branch in `on_execute` AND a new Manager module inclusion at the top of EM.

8. **Break always propagates; Next propagates only from sync**: This is the fundamental concurrency contract. Any change here affects all workflow control flow.
