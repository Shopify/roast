# Document 6: Metaprogramming Map

> **Audience**: AI coding agents navigating the Roast codebase.
> **Purpose**: Map every dynamically-defined method to its installation site, its runtime behaviour, and the manager that creates it.

---

## 1. The Core Pattern

Roast's DSL is powered by a single metaprogramming pattern repeated across three manager classes. Each manager:

1. Captures a reference to its own dispatch method via `method(:on_xxx)`.
2. Wraps it in a `proc` with the appropriate parameter signature.
3. Installs the proc on a context instance via `define_singleton_method`.

The result: three "blank" context classes (`ConfigContext`, `ExecutionContext`, `CogInputContext`) acquire methods at runtime that route to completely different behavior depending on which manager installed them.

### Source of the "blank" classes

| Class | Source | Hardcoded content |
|-------|--------|-------------------|
| `ConfigContext` | `lib/roast/config_context.rb:6` | Empty class body |
| `ExecutionContext` | `lib/roast/execution_context.rb:6` | Empty class body |
| `CogInputContext` | `lib/roast/cog_input_context.rb:6–33` | 4 control flow methods + 2 module includes |

---

## 2. ConfigContext — Methods Installed by ConfigManager

**Installer**: `ConfigManager` (`lib/roast/config_manager.rb`)

### 2.1 `global` method

| Aspect | Detail |
|--------|--------|
| **Installed by** | `ConfigManager#bind_global` (line 124) |
| **Signature** | `global(&block)` |
| **Dispatch target** | `ConfigManager#on_global` (line 135) |
| **Behavior** | Evaluates `block` via `instance_exec` on `@global_config` (a `Cog::Config` instance) |
| **Available within** | `config { }` blocks only |

**Installation code** (lines 124–132):
```ruby
def bind_global
  on_global_method = method(:on_global)
  method_to_bind = proc do |&global_proc|
    on_global_method.call(global_proc)
  end
  @config_context.instance_eval do
    define_singleton_method(:global, method_to_bind)
  end
end
```

### 2.2 Per-cog-type methods (× 7 cog types)

| Aspect | Detail |
|--------|--------|
| **Installed by** | `ConfigManager#bind_cog` (line 86) |
| **Method names** | `:agent`, `:chat`, `:cmd`, `:ruby`, `:call`, `:map`, `:repeat` |
| **Signature** | `cog_type(name_or_pattern = nil, &block)` |
| **Dispatch target** | `ConfigManager#on_config` (line 99) |
| **Dispatch routing** | `nil` → general config; `Regexp` → regexp-scoped config; `Symbol` → name-scoped config |
| **Block evaluation** | `config_object.instance_exec(&cog_config_proc)` |
| **Collision guard** | `respond_to?(cog_method_name, true)` → raises `IllegalCogNameError` (line 92) |

**Installation code** (lines 86–96):
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

### 2.3 Complete ConfigContext method table

| Method | Installer | Dispatch | Lines |
|--------|-----------|----------|-------|
| `global` | `bind_global` | `on_global` | CM:124–132 |
| `agent` | `bind_cog` | `on_config(Cogs::Agent, ...)` | CM:86–96 |
| `chat` | `bind_cog` | `on_config(Cogs::Chat, ...)` | CM:86–96 |
| `cmd` | `bind_cog` | `on_config(Cogs::Cmd, ...)` | CM:86–96 |
| `ruby` | `bind_cog` | `on_config(Cogs::Ruby, ...)` | CM:86–96 |
| `call` | `bind_cog` | `on_config(SystemCogs::Call, ...)` | CM:86–96 |
| `map` | `bind_cog` | `on_config(SystemCogs::Map, ...)` | CM:86–96 |
| `repeat` | `bind_cog` | `on_config(SystemCogs::Repeat, ...)` | CM:86–96 |

**Total**: 8 methods dynamically installed on each `ConfigContext` instance.

---

## 3. ExecutionContext — Methods Installed by ExecutionManager

**Installer**: `ExecutionManager` (`lib/roast/execution_manager.rb`)

### 3.1 `outputs` and `outputs!` methods

| Aspect | Detail |
|--------|--------|
| **Installed by** | `ExecutionManager#bind_outputs` (line 228) |
| **Signatures** | `outputs(&block)`, `outputs!(&block)` |
| **Dispatch targets** | `on_outputs` (line 240), `on_outputs!` (line 247) |
| **Behavior** | Stores the proc for later evaluation in `compute_final_output` |
| **Mutual exclusion** | Both raise `OutputsAlreadyDefinedError` if either is already set (line 241/249) |

**Installation code** (lines 228–237):
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

### 3.2 Per-cog-type methods (× 7 cog types)

| Aspect | Detail |
|--------|--------|
| **Installed by** | `ExecutionManager#bind_cog` (line 187) |
| **Method names** | `:agent`, `:chat`, `:cmd`, `:ruby`, `:call`, `:map`, `:repeat` |
| **Signature** | `cog_type(*args, **kwargs, &cog_input_proc)` |
| **Dispatch target** | `ExecutionManager#on_execute` (line 200) |
| **Collision guard** | `respond_to?(cog_method_name, true)` → raises `IllegalCogNameError` (line 193) |

**Installation code** (lines 187–197):
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

### 3.3 on_execute dispatch routing (lines 200–226)

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
      raise NotImplementedError
    end
  else
    cog_name = Array.wrap(cog_args).shift
    anonymous = !cog_name
    cog_name ||= Cog.generate_fallback_name
    cog_instance = cog_class.new(cog_name, cog_input_proc, anonymous:)
  end
  add_cog_instance(cog_instance)
end
```

**Critical design note**: System cog dispatch is hardcoded `if/elsif`, NOT polymorphic. This is intentional — Manager modules need access to EM internals (`@cog_registry`, `@config_manager`, `@all_execution_procs`, `@workflow_context`) to create child EMs.

### 3.4 Complete ExecutionContext method table

| Method | Installer | Dispatch | Lines |
|--------|-----------|----------|-------|
| `outputs` | `bind_outputs` | `on_outputs` | EM:228–237 |
| `outputs!` | `bind_outputs` | `on_outputs!` | EM:228–237 |
| `agent` | `bind_cog` | `on_execute(Cogs::Agent, ...)` | EM:187–197 |
| `chat` | `bind_cog` | `on_execute(Cogs::Chat, ...)` | EM:187–197 |
| `cmd` | `bind_cog` | `on_execute(Cogs::Cmd, ...)` | EM:187–197 |
| `ruby` | `bind_cog` | `on_execute(Cogs::Ruby, ...)` | EM:187–197 |
| `call` | `bind_cog` | `on_execute(SystemCogs::Call, ...)` | EM:187–197 |
| `map` | `bind_cog` | `on_execute(SystemCogs::Map, ...)` | EM:187–197 |
| `repeat` | `bind_cog` | `on_execute(SystemCogs::Repeat, ...)` | EM:187–197 |

**Total**: 9 methods dynamically installed on each `ExecutionContext` instance.

---

## 4. CogInputContext — Methods Installed by CogInputManager

**Installer**: `CogInputManager` (`lib/roast/cog_input_manager.rb`)

### 4.1 Per-cog-type triplets (× 7 cog types = 21 methods)

| Aspect | Detail |
|--------|--------|
| **Installed by** | `CogInputManager#bind_cog` (line 40) |
| **Method names per type** | `cog_type(:name)`, `cog_type!(:name)`, `cog_type?(:name)` |
| **Dispatch targets** | `cog_output` (line 54), `cog_output!` (line 69), `cog_output?` (line 64) |

**Installation code** (lines 40–51):
```ruby
def bind_cog(cog_method_name)
  cog_question_method_name = (cog_method_name.to_s + "?").to_sym
  cog_bang_method_name = (cog_method_name.to_s + "!").to_sym
  cog_output_method = method(:cog_output)
  cog_output_question_method = method(:cog_output?)
  cog_output_bang_method = method(:cog_output!)
  @context.instance_eval do
    define_singleton_method(cog_method_name, proc { |cog_name| cog_output_method.call(cog_name) })
    define_singleton_method(cog_question_method_name, proc { |cog_name| cog_output_question_method.call(cog_name) })
    define_singleton_method(cog_bang_method_name, proc { |cog_name| cog_output_bang_method.call(cog_name) })
  end
end
```

**Behavior of each accessor variant**:

| Variant | Method | On success | On cog not found | On cog skipped/failed/stopped/not-run |
|---------|--------|------------|------------------|---------------------------------------|
| Tolerant | `cog_output` | `output.deep_dup` | Raises `CogDoesNotExistError` | Returns `nil` |
| Strict | `cog_output!` | `output.deep_dup` | Raises `CogDoesNotExistError` | Raises specific error |
| Boolean | `cog_output?` | `true` | Raises `CogDoesNotExistError` | `false` |

**Blocking behavior**: All three call `cog.wait` (line 73) before state checks, which blocks the fiber if the cog is async and still running.

### 4.2 Workflow context accessors (10 methods)

| Aspect | Detail |
|--------|--------|
| **Installed by** | `CogInputManager#bind_workflow_context` (line 82) |
| **Timing** | Installed immediately in the constructor (line 26) |

**Installation code** (lines 82–104):
```ruby
def bind_workflow_context
  target_bang_method = method(:target!)
  targets_method = method(:targets)
  arg_question_method = method(:arg?)
  args_method = method(:args)
  kwarg_method = method(:kwarg)
  kwarg_bang_method = method(:kwarg!)
  kwarg_question_method = method(:kwarg?)
  kwargs_method = method(:kwargs)
  tmpdir_method = method(:tmpdir)
  template_method = method(:template)
  @context.instance_eval do
    define_singleton_method(:target!, proc { target_bang_method.call })
    define_singleton_method(:targets, proc { targets_method.call })
    define_singleton_method(:arg?, proc { |value| arg_question_method.call(value) })
    define_singleton_method(:args, proc { args_method.call })
    define_singleton_method(:kwarg, proc { |key| kwarg_method.call(key) })
    define_singleton_method(:kwarg!, proc { |key| kwarg_bang_method.call(key) })
    define_singleton_method(:kwarg?, proc { |key| kwarg_question_method.call(key) })
    define_singleton_method(:kwargs, proc { kwargs_method.call })
    define_singleton_method(:tmpdir, proc { tmpdir_method.call })
    define_singleton_method(:template, proc { |path, args = {}| template_method.call(path, args) })
  end
end
```

### 4.3 Hardcoded control flow methods (NOT dynamically defined)

These are defined directly in `CogInputContext` class body (`lib/roast/cog_input_context.rb:15–30`):

| Method | Raises | Line |
|--------|--------|------|
| `skip!(message = nil)` | `ControlFlow::SkipCog` | 15 |
| `fail!(message = nil)` | `ControlFlow::FailCog` | 20 |
| `next!(message = nil)` | `ControlFlow::Next` | 25 |
| `break!(message = nil)` | `ControlFlow::Break` | 30 |

### 4.4 Module-included methods (NOT dynamically defined)

**From `SystemCogs::Call::InputContext`** (`lib/roast/system_cogs/call.rb:119–158`):

| Method | Signature | Line |
|--------|-----------|------|
| `from` | `(call_cog_output, &block)` | 147 |

**From `SystemCogs::Map::InputContext`** (`lib/roast/system_cogs/map.rb:342–448`):

| Method | Signature | Line |
|--------|-----------|------|
| `collect` | `(map_cog_output, &block)` | 375 |
| `reduce` | `(map_cog_output, initial_value = nil, &block)` | 426 |

### 4.5 Complete CogInputContext method table

| Method | Source | Type | Lines |
|--------|--------|------|-------|
| `agent(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `agent!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `agent?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `chat(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `chat!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `chat?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `cmd(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `cmd!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `cmd?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `ruby(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `ruby!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `ruby?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `call(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `call!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `call?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `map(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `map!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `map?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `repeat(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `repeat!(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `repeat?(:name)` | `bind_cog` | Dynamic | CIM:40–51 |
| `target!` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `targets` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `arg?(:value)` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `args` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `kwarg(:key)` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `kwarg!(:key)` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `kwarg?(:key)` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `kwargs` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `tmpdir` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `template(path, args)` | `bind_workflow_context` | Dynamic | CIM:82–104 |
| `skip!(msg)` | Class body | Hardcoded | CIC:16 |
| `fail!(msg)` | Class body | Hardcoded | CIC:20 |
| `next!(msg)` | Class body | Hardcoded | CIC:25 |
| `break!(msg)` | Class body | Hardcoded | CIC:30 |
| `from(output, &blk)` | `Call::InputContext` module | Included | call.rb:147 |
| `collect(output, &blk)` | `Map::InputContext` module | Included | map.rb:375 |
| `reduce(output, init, &blk)` | `Map::InputContext` module | Included | map.rb:426 |

**Total**: 37 methods available on each `CogInputContext` instance (21 dynamic triplets + 10 dynamic workflow accessors + 4 hardcoded control flow + 2 module includes from `Map::InputContext` + 1 module include from `Call::InputContext`).

---

## 5. The Same Method Name, Three Behaviors

This is the most confusing aspect of the codebase. The method `agent` (for example) exists on all three contexts but does completely different things:

| Context | Call site | What happens |
|---------|-----------|--------------|
| `ConfigContext` | `config { agent(:name) { temperature 0.5 } }` | Fetches/creates a `Cog::Config` for `Cogs::Agent` scoped to `:name`, evaluates block on it |
| `ExecutionContext` | `execute { agent(:name) { "prompt" } }` | Creates a `Cogs::Agent` instance, saves the block as `@cog_input_proc`, pushes to stack |
| `CogInputContext` | `chat(:x) { agent(:name).response }` | Looks up the already-run `agent(:name)` cog, waits if async, returns `output.deep_dup` |

The method name is shared because each context's methods are installed from the same cog registry iteration. But the *implementation* comes from entirely different managers.

### Disambiguation rule for AI agents

When you see `agent(:name)` (or any cog method) in source:
1. **Is the call site inside a `config { }` block?** → It routes to `ConfigManager#on_config`.
2. **Is it inside an `execute { }` block at the top level (not inside a cog's `{ }` block)?** → It routes to `ExecutionManager#on_execute`.
3. **Is it inside a cog's input block (the `{ }` passed to a cog declaration)?** → It routes to `CogInputManager#cog_output`.

The trick: (2) and (3) are syntactically indistinguishable without understanding the nesting level. The `execute { }` block is evaluated on `ExecutionContext`, but the inner blocks (e.g., `agent(:x) { ... }`) are saved as procs and later evaluated on `CogInputContext` via `instance_exec`.

---

## 6. Custom Cog Registration

When a workflow calls `use :my_custom_cog`, the following chain executes:

```
Workflow#use (lib/roast/workflow.rb:105–126)
  ├─ require path: @workflow_path.realdirpath.dirname.join("cogs/my_custom_cog")
  ├─ Resolve class: "my_custom_cog".camelize.constantize → MyCustomCog
  ├─ Validate: MyCustomCog < Roast::Cog
  └─ @cog_registry.use(MyCustomCog)
        └─ Registry#use (lib/roast/cog/registry.rb:53)
              └─ create_registration: "MyCustomCog".demodulize.underscore.to_sym → :my_custom_cog
              └─ @cogs[:my_custom_cog] = MyCustomCog
```

Once registered, the cog is treated identically to built-in cogs during `prepare!`:

- `ConfigManager#bind_registered_cogs` → installs `my_custom_cog` on `ConfigContext`
- `ExecutionManager#bind_registered_cogs` → installs `my_custom_cog` on `ExecutionContext`
- `CogInputManager#bind_registered_cogs` → installs `my_custom_cog`, `my_custom_cog!`, `my_custom_cog?` on `CogInputContext`

### Gem-based cogs

```ruby
use :my_cog, from: "roast-my_cog"
```

This calls `require "roast-my_cog"` (the gem handles its own autoloading), then resolves and registers the class identically to local cogs.

### Name derivation algorithm

```ruby
cog_class.name.demodulize.underscore.to_sym
```

| Class | `.name` | `.demodulize` | `.underscore` | Final symbol |
|-------|---------|---------------|---------------|--------------|
| `Roast::Cogs::Agent` | `"Roast::Cogs::Agent"` | `"Agent"` | `"agent"` | `:agent` |
| `Roast::SystemCogs::Call` | `"Roast::SystemCogs::Call"` | `"Call"` | `"call"` | `:call` |
| `MyCustomCog` | `"MyCustomCog"` | `"MyCustomCog"` | `"my_custom_cog"` | `:my_custom_cog` |
| `Analyzers::CodeReview` | `"Analyzers::CodeReview"` | `"CodeReview"` | `"code_review"` | `:code_review` |

**Important**: Only the final class name component matters. The module namespace is stripped.

---

## 7. Name Collision Guards

Both `ConfigManager#bind_cog` (line 92) and `ExecutionManager#bind_cog` (line 193) check:

```ruby
raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)
```

The `true` argument includes private methods in the check. This prevents custom cogs from shadowing:
- Built-in cog names (`:agent`, `:chat`, `:cmd`, `:ruby`, `:call`, `:map`, `:repeat`)
- Ruby `Object` methods (`:freeze`, `:class`, `:send`, `:object_id`, etc.)
- Previously registered custom cogs

The check happens at **prepare time**, not at registration time. This means the error surfaces during `Workflow#prepare!` when `ConfigManager.prepare!` and `ExecutionManager.prepare!` iterate the registry.

`CogInputManager#bind_cog` (line 40) does **not** perform this check — it relies on the upstream managers to have caught collisions first.

---

## 8. Method Dispatch Through `instance_exec` and `instance_eval`

### Where each context's methods are invoked

| Context | Evaluation mechanism | Code location |
|---------|---------------------|---------------|
| `ConfigContext` | `@config_context.instance_eval(&config_proc)` | CM:29 |
| `ExecutionContext` | `@execution_context.instance_eval(&execution_proc)` | EM:83 |
| `CogInputContext` | `input_context.instance_exec(input, scope_value, scope_index, &cog_input_proc)` | Cog:79–81 |
| `CogInputContext` | `@cog_input_manager.context.instance_exec(@scope_value, @scope_index, &outputs_proc)` | EM:261 |
| `CogInputContext` | `em.cog_input_context.instance_exec(final_output, scope_value, scope_index, &block)` | call.rb:154 |
| `CogInputContext` | `em.cog_input_context.instance_exec(final_output, scope_value, scope_index, &block)` | map.rb:385 |
| `CogInputContext` | `em.cog_input_context.instance_exec(accumulator, final_output, scope_value, scope_index, &block)` | map.rb:437 |

**Key distinction**:
- `instance_eval` (ConfigContext, ExecutionContext): Block receives no arguments; `self` is the context.
- `instance_exec` (CogInputContext): Block receives explicit arguments AND `self` is the context. This is why cog input blocks receive `|my, scope_value, scope_index|` as parameters while simultaneously having access to output accessors like `cmd!(:name)`.

---

## 9. The `instance_variable_get` Back-Door Pattern

Three locations in the codebase reach into objects via `instance_variable_get` rather than public accessors. AI agents must understand these are intentional, not code smells:

| Location | Target | Ivar accessed | Why |
|----------|--------|---------------|-----|
| `ConfigManager#config_for` (line 48) | `@global_config` | `@values` | Global config may contain keys that don't belong to the cog-specific Config subclass. Using the public accessor would validate/reject unknown keys. |
| `Call::InputContext#from` (line 148) | `call_cog_output` | `@execution_manager` | Output objects are opaque to consumers. The `from` method needs EM access to retrieve `final_output` and `cog_input_context`. |
| `Map::InputContext#collect` (line 376) | `map_cog_output` | `@execution_managers` | Same pattern as above — the array of EMs is internal to the Output. |
| `Map::InputContext#reduce` (line 427) | `map_cog_output` | `@execution_managers` | Same as collect. |
| `Call::InputContext#from` (line 152) | `em` | `@scope_value` | Scope value is accessible via `attr_reader :scope_value`, but `@scope_index` is also an attr_reader. However, `instance_variable_get` is used for `@scope_value` to apply `.deep_dup` in the same call chain. |
| `Call::InputContext#from` (line 153) | `em` | `@scope_index` | To pass it to the block. |

---

## 10. RBI Shim Files — Canonical Documentation

The three RBI shim files serve as **the authoritative API reference** for dynamically-defined methods. They provide:
1. Sorbet type annotations for IDE integration
2. Extensive RDoc-style comments with usage examples
3. Type signatures for method parameters and return values

| Shim file | Documenting | Total lines |
|-----------|-------------|-------------|
| `sorbet/rbi/shims/lib/roast/config_context.rbi` | 8 ConfigContext methods | 323 lines |
| `sorbet/rbi/shims/lib/roast/execution_context.rbi` | 9 ExecutionContext methods | 496 lines |
| `sorbet/rbi/shims/lib/roast/cog_input_context.rbi` | 37 CogInputContext methods | 1,198 lines |

**Usage for AI agents**: When you need to understand what a DSL method does, look up its entry in the corresponding RBI file first. The comments there are written for human readers and are more comprehensive than the implementation code.

---

## 11. SystemCog Manager Modules — Mixed Into ExecutionManager

System cogs use `Manager` modules mixed into `ExecutionManager` to access its private state:

| Module | Source | Mixed in at | Provides |
|--------|--------|-------------|----------|
| `SystemCogs::Call::Manager` | `lib/roast/system_cogs/call.rb:87–116` | EM line 7 | `create_call_system_cog` |
| `SystemCogs::Map::Manager` | `lib/roast/system_cogs/map.rb:255–338` | EM line 8 | `create_map_system_cog`, `create_execution_manager_for_map_item`, `execute_map_in_series`, `execute_map_in_parallel` |
| `SystemCogs::Repeat::Manager` | `lib/roast/system_cogs/repeat.rb` | EM line 9 | `create_repeat_system_cog` |

These modules freely access EM instance variables (`@cog_registry`, `@config_manager`, `@all_execution_procs`, `@workflow_context`) because they execute in the EM's context after being included.

### InputContext modules — Mixed into CogInputContext

| Module | Source | Mixed in at | Provides |
|--------|--------|-------------|----------|
| `SystemCogs::Call::InputContext` | `lib/roast/system_cogs/call.rb:118–158` | CIC line 7 | `from` |
| `SystemCogs::Map::InputContext` | `lib/roast/system_cogs/map.rb:341–449` | CIC line 8 | `collect`, `reduce` |

**Note**: There is no `Repeat::InputContext` module. Repeat cogs use `Map::Output` for their `.results` field, which enables reuse of `collect` and `reduce` without a separate module.

---

## 12. The `Cog::Config` Field Macro

The `field` macro (`lib/roast/cog/config.rb`) generates getter/setter/bang method triplets:

```ruby
# Simplified from source:
def self.field(name, default: nil)
  define_method(name) do |value = :__unset__|
    if value == :__unset__
      @values[name] || default  # ← NOTE: the || fallback
    else
      @values[name] = value
    end
  end
  define_method(:"#{name}?") { !!(@values[name] || default) }
  # ... bang and no_ methods
end
```

**Critical pitfall**: The `||` fallback means `false` and `nil` stored in `@values[name]` will be treated as "not set" and the default will be returned instead. This affects boolean fields — see the `abort_on_failure?` workaround which uses `@values.fetch(:abort_on_failure, true)` instead of the field macro pattern.

---

## 13. Quick-Reference: "Where Does This Method Come From?"

### Lookup algorithm for AI agents

Given a method call `xyz(...)` in Roast DSL code:

```
1. Is it inside `config { ... }`?
   └─ YES → ConfigContext method, installed by ConfigManager#bind_cog or bind_global
   └─ NO → continue

2. Is it at the TOP level of `execute { ... }` (not inside a cog block)?
   └─ YES → ExecutionContext method, installed by ExecutionManager#bind_cog or bind_outputs
   └─ NO → continue

3. Is it inside a cog input block (agent(:x) { HERE }) or an outputs block?
   └─ YES → CogInputContext method
       ├─ Is it skip!/fail!/next!/break!? → Hardcoded in CogInputContext class body
       ├─ Is it from/collect/reduce? → Module included on CogInputContext
       ├─ Is it target!/targets/args/kwargs/tmpdir/template? → Dynamic via bind_workflow_context
       └─ Is it a cog_type name? → Dynamic triplet via bind_cog
```

### File lookup table

| If you see... | Look in... |
|---------------|-----------|
| `config { agent { ... } }` | `lib/roast/config_manager.rb` → `on_config` |
| `execute { agent(:x) { } }` | `lib/roast/execution_manager.rb` → `on_execute` |
| `chat(:x) { agent!(:y).response }` | `lib/roast/cog_input_manager.rb` → `cog_output!` |
| `config { global { } }` | `lib/roast/config_manager.rb` → `on_global` |
| `execute { outputs! { } }` | `lib/roast/execution_manager.rb` → `on_outputs!` |
| `from(call!(:x))` | `lib/roast/system_cogs/call.rb` → `InputContext#from` |
| `collect(map!(:x))` | `lib/roast/system_cogs/map.rb` → `InputContext#collect` |
| `reduce(map!(:x), 0)` | `lib/roast/system_cogs/map.rb` → `InputContext#reduce` |
| `skip!` / `fail!` / `next!` / `break!` | `lib/roast/cog_input_context.rb` (hardcoded) |
| `target!` / `targets` / `args` / `kwargs` | `lib/roast/cog_input_manager.rb` → `bind_workflow_context` |
| `template("path")` | `lib/roast/cog_input_manager.rb` → `#template` (line 182) |

---

## 14. Timing: When Are Methods Installed?

| Phase | What happens | Methods available after |
|-------|--------------|------------------------|
| `Workflow.new` | Registry populated (7 built-in cogs) | — |
| `extract_dsl_procs!` | `use` may add custom cogs to registry | — |
| `ConfigManager.prepare!` | `bind_global` + `bind_registered_cogs` on ConfigContext | ConfigContext fully armed |
| | Config procs evaluated (`instance_eval`) | — |
| `ExecutionManager.prepare!` | `bind_outputs` + `bind_registered_cogs` on ExecutionContext | ExecutionContext fully armed |
| | Execution procs evaluated (`instance_eval`) | — |
| `CogInputManager.new` (inside EM.new) | `bind_registered_cogs` + `bind_workflow_context` on CogInputContext | CogInputContext fully armed |

**Critical implication**: Custom cogs registered via `use` in the workflow definition file are available on all three contexts because `extract_dsl_procs!` runs before any manager's `prepare!`. But you cannot conditionally register cogs — `use` is evaluated at the `Workflow` level before contexts exist.

---

## 15. Method Count Summary

| Context | Dynamic methods | Hardcoded methods | Module methods | Total |
|---------|----------------|-------------------|----------------|-------|
| ConfigContext | 8 | 0 | 0 | **8** |
| ExecutionContext | 9 | 0 | 0 | **9** |
| CogInputContext | 31 | 4 | 3 | **38** |
| **Grand total** | **48** | **4** | **3** | **55** |

With 7 built-in cog types. Each additional custom cog adds:
- +1 method to ConfigContext
- +1 method to ExecutionContext
- +3 methods to CogInputContext (triplet)
- = **+5 methods per custom cog**
