# Document 9: Error Hierarchy

> **Audience**: AI agents (primary — for exception handling changes), Intern (reference)
>
> **Purpose**: Complete error tree with descriptions of when each error is raised, by whom, and whether it propagates or is caught internally.

---

## 1. The Four Root Branches

The Roast framework has **four independent exception hierarchies**, each rooted directly in `StandardError`:

```
StandardError
├── Roast::Error                        # lib/roast/error.rb:6
│   └── (all framework errors — see §2)
│
├── Roast::CommandRunner::CommandRunnerError   # lib/roast/command_runner.rb:19
│   ├── NoCommandProvidedError                # lib/roast/command_runner.rb:21
│   └── TimeoutError                          # lib/roast/command_runner.rb:23
│
├── Roast::EventMonitor::EventMonitorError    # lib/roast/event_monitor.rb:9
│   ├── EventMonitorAlreadyStartedError       # lib/roast/event_monitor.rb:11
│   └── EventMonitorNotRunningError           # lib/roast/event_monitor.rb:13
│
└── Roast::ControlFlow::Base                  # lib/roast/control_flow.rb:7
    ├── SkipCog                               # lib/roast/control_flow.rb:11
    ├── FailCog                               # lib/roast/control_flow.rb:16
    ├── Next                                  # lib/roast/control_flow.rb:25
    └── Break                                 # lib/roast/control_flow.rb:37
```

### Critical Design Consequence

`rescue Roast::Error` will **NOT** catch:
- `CommandRunnerError` (infrastructure — external process failures)
- `EventMonitorError` (infrastructure — logging subsystem)
- `ControlFlow::*` (not "errors" at all — they are flow control signals)

This is intentional. `Roast::Error` represents programming/configuration mistakes in the framework. The other branches represent orthogonal concerns.

---

## 2. The Complete `Roast::Error` Tree

```
Roast::Error                                              # lib/roast/error.rb:6
│
├── Workflow::WorkflowError                               # lib/roast/workflow.rb:6
│   ├── WorkflowNotPreparedError                          # lib/roast/workflow.rb:8
│   ├── WorkflowAlreadyPreparedError                      # lib/roast/workflow.rb:10
│   ├── WorkflowAlreadyStartedError                       # lib/roast/workflow.rb:12
│   └── InvalidLoadableReference                          # lib/roast/workflow.rb:14
│
├── ExecutionManager::ExecutionManagerError                # lib/roast/execution_manager.rb:11
│   ├── ExecutionManagerNotPreparedError                   # lib/roast/execution_manager.rb:13
│   ├── ExecutionManagerAlreadyPreparedError               # lib/roast/execution_manager.rb:15
│   ├── ExecutionManagerCurrentlyRunningError              # lib/roast/execution_manager.rb:17
│   ├── ExecutionScopeDoesNotExistError                   # lib/roast/execution_manager.rb:19
│   ├── ExecutionScopeNotSpecifiedError                   # lib/roast/execution_manager.rb:21
│   ├── IllegalCogNameError                               # lib/roast/execution_manager.rb:23
│   └── OutputsAlreadyDefinedError                        # lib/roast/execution_manager.rb:25
│
├── ConfigManager::ConfigManagerError                     # lib/roast/config_manager.rb:6
│   ├── ConfigManagerNotPreparedError                     # lib/roast/config_manager.rb:7
│   ├── ConfigManagerAlreadyPreparedError                 # lib/roast/config_manager.rb:8
│   └── IllegalCogNameError                               # lib/roast/config_manager.rb:9
│
├── Cog::CogError                                        # lib/roast/cog.rb:6
│   └── CogAlreadyStartedError                           # lib/roast/cog.rb:8
│
├── Cog::Config::ConfigError                             # lib/roast/cog/config.rb:13
│   └── InvalidConfigError                               # lib/roast/cog/config.rb:16
│
├── Cog::Input::InputError                               # lib/roast/cog/input.rb:20
│   └── InvalidInputError                                # lib/roast/cog/input.rb:23
│
├── Cog::Registry::CogRegistryError                      # lib/roast/cog/registry.rb:9
│   └── CouldNotDeriveCogNameError                       # lib/roast/cog/registry.rb:12
│
├── Cog::Store::CogAlreadyDefinedError                   # lib/roast/cog/store.rb:7
│
├── CogInputContext::CogInputContextError                # lib/roast/cog_input_context.rb:10
│   └── ContextNotFoundError                             # lib/roast/cog_input_context.rb:12
│
├── CogInputManager::CogOutputAccessError                # lib/roast/cog_input_manager.rb:7
│   ├── CogDoesNotExistError                             # lib/roast/cog_input_manager.rb:9
│   ├── CogNotYetRunError                                # lib/roast/cog_input_manager.rb:11
│   ├── CogSkippedError                                  # lib/roast/cog_input_manager.rb:13
│   ├── CogFailedError                                   # lib/roast/cog_input_manager.rb:15
│   └── CogStoppedError                                  # lib/roast/cog_input_manager.rb:17
│
├── Map::MapOutputAccessError                            # lib/roast/system_cogs/map.rb:13
│   └── MapIterationDidNotRunError                       # lib/roast/system_cogs/map.rb:19
│
├── Agent::AgentCogError                                 # lib/roast/cogs/agent.rb:23
│   ├── UnknownProviderError                             # lib/roast/cogs/agent.rb:26
│   ├── MissingProviderError                             # lib/roast/cogs/agent.rb:29
│   └── MissingPromptError                               # lib/roast/cogs/agent.rb:32
│
├── Agent::Providers::Claude::ClaudeInvocation::ClaudeInvocationError  # ...claude_invocation.rb:10
│   ├── ClaudeNotStartedError                            # ...claude_invocation.rb:12
│   ├── ClaudeAlreadyStartedError                        # ...claude_invocation.rb:14
│   ├── ClaudeNotCompletedError                          # ...claude_invocation.rb:16
│   └── ClaudeFailedError                                # ...claude_invocation.rb:18
│
└── Agent::Providers::Pi::PiInvocation::PiInvocationError             # ...pi_invocation.rb:10
    ├── PiNotStartedError                                # ...pi_invocation.rb:12
    ├── PiAlreadyStartedError                            # ...pi_invocation.rb:14
    ├── PiNotCompletedError                              # ...pi_invocation.rb:16
    └── PiFailedError                                    # ...pi_invocation.rb:18
```

**Total**: 4 root branches, 14 intermediate error classes, 38 leaf error classes.

---

## 3. Key Design Observations

### 3.1 Consumer-Side vs Producer-Side Separation

`CogOutputAccessError` is **NOT** under `CogError`. This is deliberate:

| Branch | Perspective | Meaning |
|--------|-------------|---------|
| `CogError` | Producer-side | Something went wrong *inside* the cog (e.g., started twice) |
| `CogOutputAccessError` | Consumer-side | Something went wrong when another cog *tried to access* this cog's output |

A `rescue CogError` will never catch output access failures, and vice versa. The consumer doesn't need to know *why* a cog failed internally — only that its output is unavailable.

### 3.2 Duplicate `IllegalCogNameError`

Both `ExecutionManager` and `ConfigManager` define their own `IllegalCogNameError`. These are **not** the same class — they share a name but have different parents. Both are raised during `prepare!` when a cog name collides with an existing method on the respective context:

- `ConfigManager::IllegalCogNameError` — raised at `config_manager.rb:92`
- `ExecutionManager::IllegalCogNameError` — raised at `execution_manager.rb:193`

### 3.3 Infrastructure Errors Are Intentionally Isolated

`CommandRunnerError` and `EventMonitorError` inherit directly from `StandardError`, not from `Roast::Error`. This means a `rescue Roast::Error` in application code will not inadvertently swallow infrastructure failures. If a command times out or the event monitor fails to start, those are operational errors that should propagate to the top level.

### 3.4 ControlFlow Exceptions Are Not Errors

The `ControlFlow::Base` branch represents **workflow steering signals**, not error conditions. They inherit from `StandardError` (not `Roast::Error`) because they must be raiseable/rescuable, but they carry no error semantics. See [Document 7: Control Flow Reference](07-control-flow-reference.md) for complete propagation semantics.

---

## 4. Per-Error Reference

### Lifecycle Guard Errors

These prevent invalid state transitions. They indicate programmer error (calling methods in wrong order or calling them twice).

| Error | Raised by | When |
|-------|-----------|------|
| `WorkflowNotPreparedError` | `Workflow#start!` (line 62) | `start!` called before `prepare!` |
| `WorkflowAlreadyPreparedError` | `Workflow#prepare!` (line 47) | `prepare!` called twice |
| `WorkflowAlreadyStartedError` | `Workflow#start!` (line 63) | `start!` called twice |
| `ExecutionManagerNotPreparedError` | `EM#run!` (line 88), `EM#execution_context` (line 140) | `run!` or context accessed before `prepare!` |
| `ExecutionManagerAlreadyPreparedError` | `EM#prepare!` (line 78) | `prepare!` called twice |
| `ExecutionManagerCurrentlyRunningError` | `EM#run!` (line 89) | `run!` called while already running |
| `ConfigManagerNotPreparedError` | `CM#config_for` (line 45) | Config accessed before `prepare!` |
| `ConfigManagerAlreadyPreparedError` | `CM#prepare!` (line 24) | `prepare!` called twice |
| `CogAlreadyStartedError` | `Cog#run!` (line 72) | `run!` called on a cog that already has a task |

**Caught internally?** Never — these always propagate to the caller.

---

### Registration & Naming Errors

These occur during `prepare!` when the cog graph is being assembled.

| Error | Raised by | When |
|-------|-----------|------|
| `InvalidLoadableReference` | `Workflow#resolve_and_validate_loadable` (line 117, 123) | `use` references a class that doesn't exist or isn't a valid Roast primitive |
| `CogAlreadyDefinedError` | `Cog::Store#push` (line 21) | Two cogs with the same name in the same scope |
| `CouldNotDeriveCogNameError` | `Cog::Registry#derive_name` (line 63) | A custom cog class can't be converted to a method name via `demodulize.underscore` |
| `IllegalCogNameError` (EM) | `EM#bind_cog` (line 193) | Cog name collides with existing method on ExecutionContext |
| `IllegalCogNameError` (CM) | `CM#bind_registered_cogs` (line 92) | Cog name collides with existing method on ConfigContext |

**Caught internally?** Never — these always propagate.

---

### Configuration Errors

| Error | Raised by | When |
|-------|-----------|------|
| `InvalidConfigError` | `Config#validate!` overrides, `Config#working_directory` (lines 297–298), `Map::Config#valid_parallel!` (line 89), `Chat::Config#valid_api_key!` (line 102), `Chat::Config#valid_provider!` (line 41), `Agent::Config#valid_provider!` (line 41) | A config value is invalid or missing after the merge cascade completes |

**Caught internally?** Never — propagates as a fatal workflow configuration error.

---

### Input Errors

| Error | Raised by | When |
|-------|-----------|------|
| `InvalidInputError` | `Input#validate!` overrides in every cog type | Input to a cog is missing or invalid **after** coercion has been attempted |

**Caught internally?** YES — the first `validate!` failure triggers the coercion path (`coerce(return_value)`), after which `validate!` is called again. Only the *second* failure propagates. See `Cog#run!` and `Cog::Input#coerce_and_validate_input!`.

---

### Output Access Errors

These form the graduated tolerance model used by `CogInputManager`.

| Error | Raised by | When | Tolerant mode (`cog_output`) | Strict mode (`cog_output!`) |
|-------|-----------|------|------------------------------|----------------------------|
| `CogDoesNotExistError` | `cog_output!` (line 70) | Referenced cog name doesn't exist in scope | **Re-raises** (line 58) | Raises |
| `CogNotYetRunError` | `cog_output!` (line 77) | Cog hasn't completed yet (sync cog not yet reached) | Swallows → `nil` | Raises |
| `CogSkippedError` | `cog_output!` (line 74) | Cog was skipped via `skip!` or stopped via `next!`/`break!` | Swallows → `nil` | Raises |
| `CogFailedError` | `cog_output!` (line 75) | Cog failed via `fail!` | Swallows → `nil` | Raises |
| `CogStoppedError` | `cog_output!` (line 76) | Cog was stopped by barrier interruption | Swallows → `nil` | Raises |

**Also caught by `compute_final_output`**: The `outputs` block (non-bang) catches `CogNotYetRunError`, `CogSkippedError`, and `CogStoppedError` (line 274), swallowing them. `CogFailedError` is NOT caught by `compute_final_output` and always propagates.

---

### Scope & Context Errors

| Error | Raised by | When |
|-------|-----------|------|
| `ExecutionScopeDoesNotExistError` | `EM#run!` (line 164) | `run:` param references a scope name that was never declared |
| `ExecutionScopeNotSpecifiedError` | `Call::Manager` (line 94), `Map::Manager` (line 261), `Repeat::Manager` (line 211) | System cog created without `run:` parameter |
| `OutputsAlreadyDefinedError` | `EM#on_outputs` (line 241), `EM#on_outputs!` (line 248) | Two `outputs`/`outputs!` blocks declared in same scope |
| `ContextNotFoundError` | `CogInputManager#resolve_template_path` (line 219), `Call::InputContext#from` (line 149), `Map::InputContext#collect` (line 377), `Map::InputContext#reduce` (line 428) | Template file not found, or `from`/`collect`/`reduce` called with nil EM |
| `MapIterationDidNotRunError` | `Map::Output#iteration` (line 220) | Accessing a map iteration that was broken/never executed |

**Caught internally?** `ContextNotFoundError` in template resolution propagates to `Cog#run!`. The others always propagate.

---

### Agent Provider Errors

| Error | Raised by | When |
|-------|-----------|------|
| `UnknownProviderError` | `Agent#execute` (line 66) | Config specifies an unrecognized provider name |
| `MissingProviderError` | (defined but not currently raised in source) | Reserved for future use |
| `MissingPromptError` | (defined but not currently raised in source) | Reserved for future use |
| `ClaudeAlreadyStartedError` | `ClaudeInvocation#start!` (line 77) | `start!` called on running invocation |
| `ClaudeNotStartedError` | `ClaudeInvocation#result!` (line 121) | `result!` called before `start!` |
| `ClaudeNotCompletedError` | `ClaudeInvocation#result!` (line 123) | `result!` called before process completes |
| `ClaudeFailedError` | `ClaudeInvocation#result!` (line 122), `#process_message` (line 172) | Claude process exits with error or reports error message |
| `PiAlreadyStartedError` | `PiInvocation#start!` (line 80) | Same as Claude equivalent |
| `PiNotStartedError` | `PiInvocation#result!` (line 128) | Same as Claude equivalent |
| `PiNotCompletedError` | `PiInvocation#result!` (line 130) | Same as Claude equivalent |
| `PiFailedError` | `PiInvocation#result!` (line 129) | Same as Claude equivalent |

**Caught internally?** None are caught internally. These propagate through `Cog#run!`'s `rescue StandardError => e` on line 96, which sets `@failed = true` and re-raises.

---

### Infrastructure Errors

| Error | Raised by | When |
|-------|-----------|------|
| `NoCommandProvidedError` | `CommandRunner.execute` (line 62) | Empty args array passed to execute |
| `TimeoutError` | `CommandRunner.execute` (line 136) | Command exceeds configured timeout |
| `EventMonitorAlreadyStartedError` | `EventMonitor.start!` (line 25) | `start!` called when queue is already open |
| `EventMonitorNotRunningError` | `EventMonitor.stop!` (line 42) | `stop!` called when queue is already closed |

**Caught internally?** `TimeoutError` is not caught — it propagates through the cmd cog's execute method. `EventMonitor` errors propagate to the CLI bootstrap.

---

## 5. Error Handling Strategy Summary

| Layer | What it catches | What propagates |
|-------|----------------|-----------------|
| `Cog#run!` | `SkipCog`, `FailCog` (conditionally), stores `@error` for all others | `Next`, `Break`, `StandardError` (if `abort_on_failure?`) |
| `ExecutionManager#run!` (sync) | Nothing — re-raises immediately after `wait` | Everything |
| `ExecutionManager#run!` (async barrier) | `Next` (swallowed), `Break` (stored + re-raised) | `Break`, other errors |
| `compute_final_output` | `SkipCog`, `Next` (in outputs eval), `CogNotYetRunError`, `CogSkippedError`, `CogStoppedError` | `CogFailedError`, `CogDoesNotExistError` |
| `Call::Manager` | `Next`, `Break` (both treated as scope termination) | Nothing further |
| `Map::Manager` (serial) | `Next` (continue), `Break` (stop iterations) | Nothing further |
| `Map::Manager` (parallel) | `Next` (per-fiber), `Break` (stops barrier) | Nothing further |
| `Repeat::Manager` | `Break` only | `Next` (⚠️ BUG — escapes loop) |
| `Workflow#start!` | `Break` (graceful termination) | `Next` (⚠️ BUG — unhandled) |

---

## 6. See Also

- [Document 7: Control Flow Reference](07-control-flow-reference.md) — Full propagation matrix for ControlFlow exceptions
- [Document 5: Execution Engine Internals](05-execution-engine-internals.md) — Where in the code each rescue lives
- [Document 12: Known Issues & Gotchas](12-known-issues-and-gotchas.md) — The Repeat+Next and top-level Next bugs
