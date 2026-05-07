# Cog Reference

> **Per-cog reference cards.** This document provides exhaustive detail on every
> cog type: configuration options, input fields, output fields, execute behavior,
> defaults, and source locations. Consult this when you need to know exactly what
> a cog can do and how it's configured.
>
> Prerequisite: [01-architecture-overview.md](01-architecture-overview.md) (for
> the base cog lifecycle: Config → Input → Execute → Output).

---

## Table of Contents

1. [Common Configuration (All Cogs)](#1-common-configuration-all-cogs)
2. [cmd Cog](#2-cmd-cog)
3. [chat Cog](#3-chat-cog)
4. [agent Cog](#4-agent-cog)
5. [ruby Cog](#5-ruby-cog)
6. [call System Cog](#6-call-system-cog)
7. [map System Cog](#7-map-system-cog)
8. [repeat System Cog](#8-repeat-system-cog)
9. [Config Merge Cascade](#9-config-merge-cascade)
10. [Output Mixin Modules](#10-output-mixin-modules)
11. [Boolean Default Patterns](#11-boolean-default-patterns)

---

## 1. Common Configuration (All Cogs)

**Source**: `lib/roast/cog/config.rb`

Every cog inherits these options from `Cog::Config`. They are set inside
`config {}` blocks and are subject to the merge cascade (§9).

### Async Execution

| Method | Effect | Stored Value |
|---|---|---|
| `async!` | Run cog in background | `@values[:async] = true` |
| `no_async!` | Run cog synchronously (default) | `@values[:async] = false` |
| `sync!` | Alias for `no_async!` | `@values[:async] = false` |

**Query**: `async?` → `!!@values[:async]` → defaults to **`false`** (sync).

When async, the next cog in the stack starts immediately. Accessing the async
cog's output via `cog!(:name)` blocks the caller until the cog completes.

### Abort On Failure

| Method | Effect | Stored Value |
|---|---|---|
| `abort_on_failure!` | Abort workflow on cog failure (default) | `@values[:abort_on_failure] = true` |
| `no_abort_on_failure!` | Continue workflow on cog failure | `@values[:abort_on_failure] = false` |
| `continue_on_failure!` | Alias for `no_abort_on_failure!` | `@values[:abort_on_failure] = false` |

**Query**: `abort_on_failure?` → `@values.fetch(:abort_on_failure, true)` →
defaults to **`true`** (abort). (`config.rb`, line 233)

**Scope**: This setting only affects `ControlFlow::FailCog` exceptions (raised
via `fail!` or by `cmd` on non-zero exit with `fail_on_error?`). Unexpected
`StandardError` exceptions (e.g., `RuntimeError`, `NoMethodError`) **always
propagate** and abort the workflow regardless of this setting.

### Working Directory

| Method | Effect |
|---|---|
| `working_directory("/path")` | Run external commands in the specified directory |
| `use_current_working_directory!` | Use the directory from which Roast was invoked (default) |

**Query**: `valid_working_directory` → returns `Pathname?` (`nil` = use cwd).
Raises `InvalidConfigError` if the path does not exist or is not a directory.

**Important**: This only affects external commands invoked by a cog (via
`CommandRunner`). It does not change Roast's own process working directory.

### The `field` Macro (For Custom Cogs)

`Cog::Config` provides a class method `field(key, default, &validator)` that
generates a dual-purpose getter/setter and a `use_default_{key}!` reset method.
(`config.rb`, lines 110–128)

⚠️ **Falsy value pitfall**: The getter uses `@values[key] || default.deep_dup`.
This means `false` and `nil` values **fall through to the default**. All
built-in boolean options avoid this macro and use direct `@values` manipulation
instead. See §11 for the full pattern catalog.

### Hash-Style Access

`config[key]` and `config[key] = value` provide direct `@values` hash access
for simple custom cog use cases. (`config.rb`, lines 61–77)

---

## 2. cmd Cog

**Source**: `lib/roast/cogs/cmd.rb`  
**Purpose**: Execute a shell command via `CommandRunner`.

### Config (`Cmd::Config`)

| Method | Default | Pattern | Effect |
|---|---|---|---|
| `fail_on_error!` | **enabled** | `@values[:fail_on_error] != false` | Mark cog as failed on non-zero exit |
| `no_fail_on_error!` | | | Allow non-zero exit without failure |
| `show_stdout!` | disabled | `!!@values[:show_stdout]` | Print command stdout to console |
| `show_stderr!` | disabled | `!!@values[:show_stderr]` | Print command stderr to console |
| `display!` | | | Enable both stdout and stderr |
| `no_display!` / `quiet!` | | | Disable both stdout and stderr |

**Queries**: `fail_on_error?`, `show_stdout?`, `show_stderr?`, `display?`

Note the behavioral interaction: `fail_on_error?` marks the cog as failed (via
`ControlFlow::FailCog`), and then `abort_on_failure?` determines whether that
failure aborts the workflow. By default, both are true: a non-zero exit will
abort the workflow.

### Input (`Cmd::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `command` | `String?` | Yes | `nil` |
| `args` | `Array[String]` | No | `[]` |
| `stdin` | `String?` | No | `nil` |

**Validation**: `command.present?` is required. (`cmd.rb`, line 208)

**Coercion** (`cmd.rb`, lines 222–230):
- `String` → sets `command`
- `Array` → first element becomes `command`, remaining become `args` (elements
  coerced to strings via `.to_s`; uses `shift` which mutates the array)

### Output (`Cmd::Output`)

| Field | Type | Description |
|---|---|---|
| `out` | `String` | The command's stdout |
| `err` | `String` | The command's stderr |
| `status` | `Process::Status` | The exit status object |

**Includes**: `WithJson`, `WithNumber`, `WithText` (see §10)

**`raw_text`** → delegates to `out` (stdout is the "primary" output for text/JSON/number parsing)

### Execute Behavior

1. Creates streaming handlers based on `show_stdout?` / `show_stderr?`
   (`cmd.rb`, lines 277–278)
2. Delegates to `CommandRunner.execute` with the command + args array,
   `working_directory`, `stdin_content`, and handlers (`cmd.rb`, lines 280–287)
3. If the process exits non-zero AND `fail_on_error?` is true: raises
   `ControlFlow::FailCog` (`cmd.rb`, lines 288–289)
4. Returns `Output.new(stdout, stderr, status)`

**Source**: `lib/roast/command_runner.rb` handles the subprocess lifecycle:
`Bundler.with_unbundled_env` → `Open3.popen3` → concurrent stdout/stderr
reading via `Async` tasks → process cleanup with SIGTERM → SIGKILL fallback.

---

## 3. chat Cog

**Source**: `lib/roast/cogs/chat.rb`, `lib/roast/cogs/chat/config.rb`,
`lib/roast/cogs/chat/input.rb`, `lib/roast/cogs/chat/output.rb`,
`lib/roast/cogs/chat/session.rb`  
**Purpose**: Single LLM conversation turn via the `RubyLLM` gem. No local
filesystem access, no local tools — only the model and any cloud-based tools or
MCP servers provided by the LLM provider.

### Config (`Chat::Config`)

#### Provider & Credentials

| Method | Default | Effect |
|---|---|---|
| `provider(:openai)` | `:openai` | Set the LLM provider |
| `use_default_provider!` | | Reset to default provider |
| `api_key("sk-...")` | from ENV | Set an explicit API key |
| `use_api_key_from_environment!` | | Clear explicit key, fall back to `OPENAI_API_KEY` |
| `base_url("https://...")` | from ENV or `https://api.openai.com/v1` | Set the API base URL |
| `use_default_base_url!` | | Reset to env var or provider default |

**Currently only one provider is supported**: `:openai`. The `PROVIDERS` hash
(`chat/config.rb`, lines 8–15) maps `:openai` to its env var names and defaults.

**Validated getters**: `valid_provider!`, `valid_api_key!` (raises
`InvalidConfigError` if missing), `valid_base_url` (falls back through env →
provider default).

#### Model & Temperature

| Method | Default | Effect |
|---|---|---|
| `model("gpt-4o")` | `"gpt-4o-mini"` | Set the model name |
| `use_default_model!` | | Reset to provider default |
| `temperature(0.7)` | provider default (no explicit value) | Set temperature (0.0–1.0) |
| `use_default_temperature!` | | Remove explicit temperature |
| `verify_model_exists!` | disabled | Check model availability before invocation |
| `no_verify_model_exists!` / `assume_model_exists!` | | Skip model verification (default) |

**Validated getters**: `valid_model` (returns model or provider default),
`valid_temperature` (returns `Float?`, `nil` means use provider default),
`verify_model_exists?` → `@values.fetch(:verify_model_exists, false)`.

#### Display Options

| Method | Default | Pattern |
|---|---|---|
| `show_prompt!` / `no_show_prompt!` | **disabled** | `@values.fetch(:show_prompt, false)` |
| `show_response!` / `no_show_response!` | **enabled** | `@values.fetch(:show_response, true)` |
| `show_stats!` / `no_show_stats!` | **enabled** | `@values.fetch(:show_stats, true)` |
| `display!` | | Enable all three |
| `no_display!` / `quiet!` | | Disable all three |

**Query**: `display?` → `show_prompt? || show_response? || show_stats?`

### Input (`Chat::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `prompt` | `String?` | Yes | `nil` |
| `session` | `Session?` | No | `nil` |

**Validation**: Calls `valid_prompt!`, which raises `InvalidInputError` if
`prompt` is not `present?`. (`chat/input.rb`, lines 41–42, 68–71)

**Coercion** (`chat/input.rb`, lines 53–56):
- `String` → sets `prompt`
- Other types → ignored (no coercion)

Note: Chat's `coerce` does **not** call `super`, so the `coerce_ran?` flag is
never set. This is safe because Chat's `validate!` doesn't check `coerce_ran?`.

**Helper methods**: `valid_prompt!` (raises if blank), `valid_session` (returns
session or `nil` — no raise on missing session).

### Output (`Chat::Output`)

| Field | Type | Description |
|---|---|---|
| `response` | `String` | The LLM's response text |
| `session` | `Session` | Conversation context for resumption |

**Includes**: `WithJson`, `WithNumber`, `WithText`

**`raw_text`** → delegates to `response`

### Session (`Chat::Session`)

**Source**: `lib/roast/cogs/chat/session.rb`

The session captures the conversation message history for fork-style resumption.

| Method | Behavior |
|---|---|
| `Session.from_chat(chat)` | Creates a session from a RubyLLM::Chat, **deep_dup**'ing all messages |
| `session.first(n=2)` | Returns a new session with only the first `n` messages (deep_dup'd) |
| `session.last(n=2)` | Returns a new session with only the last `n` messages (deep_dup'd) |
| `session.apply!(chat)` | Replaces the chat's `@messages` via `instance_variable_set` (deep_dup'd); also restores temperature if captured |

**Fork semantics**: Every `apply!` call deep-copies the messages, so multiple
downstream cogs can fork from the same session state independently.

⚠️ **`instance_variable_set` boundary**: `apply!` reaches into RubyLLM's
internals to replace `@messages` (`session.rb`, line 60). This is a fragile
coupling to RubyLLM's internal structure.

### Execute Behavior

1. Get or create a `RubyLLM::Context` (memoized per cog instance, configured
   with `api_key` and `base_url`) (`chat.rb`, lines 71–76)
2. Create a new `RubyLLM::Chat` with the configured model, provider, and
   `assume_model_exists` flag (`chat.rb`, lines 32–36)
3. Apply input session if present (fork semantics via deep_dup) (`chat.rb`,
   line 37)
4. Set temperature via `chat.with_temperature` if configured (`chat.rb`, line 38)
5. Record `num_existing_messages` for display filtering (`chat.rb`, line 39)
6. `chat.ask(prompt)` — the actual LLM call (`chat.rb`, line 41)
7. Display new messages based on config (prompt → `[USER PROMPT]`, response →
   `[LLM RESPONSE]`) (`chat.rb`, lines 42–53)
8. Display stats if enabled: model, temperature, input/output tokens. Temperature
   is read via `chat.instance_variable_get(:@temperature)` (`chat.rb`, lines
   54–61)
9. Return `Output.new(Session.from_chat(chat), response.content)`

⚠️ **`instance_variable_get` boundary**: Stats display reaches into RubyLLM's
`@temperature` internal (`chat.rb`, line 55). This is the second fragile
coupling to RubyLLM internals in this cog.

---

## 4. agent Cog

**Source**: `lib/roast/cogs/agent.rb`, `lib/roast/cogs/agent/config.rb`,
`lib/roast/cogs/agent/input.rb`, `lib/roast/cogs/agent/output.rb`,
`lib/roast/cogs/agent/provider.rb`, `lib/roast/cogs/agent/providers/claude.rb`,
`lib/roast/cogs/agent/providers/pi.rb`  
**Purpose**: Invoke an AI coding agent on the local machine. The agent has full
filesystem access, local tools, and MCP servers. Session state is maintained
across invocations via session identifiers.

### Error Hierarchy

```
Roast::Error
  └── AgentCogError
        ├── UnknownProviderError    — invalid provider name
        ├── MissingProviderError    — no provider configured
        └── MissingPromptError      — no prompt provided
```

### Config (`Agent::Config`)

#### Provider & Command

| Method | Default | Effect |
|---|---|---|
| `provider(:claude)` | `:claude` | Set the agent provider |
| `use_default_provider!` | | Reset to default (`:claude`) |
| `command("claude")` | provider default | Override the CLI command |
| `use_default_command!` | | Reset to provider default |
| `model("claude-sonnet-4-20250514")` | provider default | Set the model name |
| `use_default_model!` | | Reset to provider default |

**Valid providers**: `[:claude, :pi]` (`agent/config.rb`, line 8)

**Validated getters**: `valid_provider!` (raises if invalid), `valid_command`
(returns `nil` for provider default), `valid_model` (returns `nil` for provider
default — uses `.presence`).

#### System Prompt

| Method | Default | Effect |
|---|---|---|
| `replace_system_prompt("...")` | none | Completely replace the agent's default system prompt |
| `no_replace_system_prompt!` | | Clear replacement (restore default) |
| `append_system_prompt("...")` | none | Append text to the agent's system prompt |
| `no_append_system_prompt!` | | Clear append text |

`replace_system_prompt` and `append_system_prompt` **can be combined**: the
replacement is applied first, then the append is added to the end.

**Validated getters**: `valid_replace_system_prompt`, `valid_append_system_prompt`
— both return `String?` via `.presence` (blank strings → `nil`).

#### Permissions

| Method | Default | Pattern |
|---|---|---|
| `apply_permissions!` / `no_skip_permissions!` | **enabled** | `@values.fetch(:apply_permissions, true)` |
| `no_apply_permissions!` / `skip_permissions!` | | Disable permissions |

**Query**: `apply_permissions?` → defaults to `true`.

When disabled, the agent is invoked with `--dangerously-skip-permissions`
(Claude) — this bypasses all permission checks. Pi does not support this flag.

#### Display Options

| Method | Default | Pattern |
|---|---|---|
| `show_prompt!` / `no_show_prompt!` | **disabled** | `@values.fetch(:show_prompt, false)` |
| `show_progress!` / `no_show_progress!` | **enabled** | `@values.fetch(:show_progress, true)` |
| `show_response!` / `no_show_response!` | **enabled** | `@values.fetch(:show_response, true)` |
| `show_stats!` / `no_show_stats!` | **enabled** | `@values.fetch(:show_stats, true)` |
| `display!` | | Enable all four |
| `no_display!` / `quiet!` | | Disable all four |

**Query**: `display?` → any of the four enabled.

#### Debug

| Method | Effect |
|---|---|
| `dump_raw_agent_messages_to("filename")` | Dump raw agent messages to file (dev/debug) |

**Validated getter**: `valid_dump_raw_agent_messages_to_path` → `Pathname?`

### Input (`Agent::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `prompts` | `Array[String]` | Yes (at least one) | `[]` |
| `session` | `String?` | No | `nil` |

**Validation**: Requires non-empty `prompts` with no blank entries.
(`agent/input.rb`, lines 46–48)

**Coercion** (`agent/input.rb`, lines 61–67):
- `String` → `[string]` (single-element prompts array)
- `Array` → elements coerced via `.map(&:to_s)`

**Convenience setter**: `prompt=(str)` → wraps in `[str]` (`agent/input.rb`,
line 71)

**Multi-prompt semantics**: When multiple prompts are provided, each is sent to
the agent sequentially in the same session. The agent completes one prompt before
receiving the next. This is designed for "perform task, then summarize" patterns.

### Output (`Agent::Output`)

| Field | Type | Description |
|---|---|---|
| `response` | `String` | The agent's final response text |
| `session` | `String` | Session identifier for resumption |
| `stats` | `Stats` | Execution statistics |

**Includes**: `WithJson`, `WithNumber`, `WithText`

**`raw_text`** → delegates to `response`

Note: `Agent::Output` defines `attr_reader` but **no constructor**. Construction
is handled by provider-specific Output subclasses (`Claude::Output`,
`Pi::Output`) that delegate to their respective `Result` classes.

### Stats & Usage (`agent/stats.rb`, `agent/usage.rb`)

| Class | Fields |
|---|---|
| `Stats` | `duration_ms`, `num_turns`, `usage` (aggregate), `model_usage` (Hash[String, Usage]) |
| `Usage` | `input_tokens`, `output_tokens`, `cost_usd` — all nullable |

Both classes support the `+` operator for merging across multi-prompt
invocations. `Stats#to_s` produces human-readable output using
`ActiveSupport::NumberHelper` and `ActiveSupport::Duration`.

### Providers

Both providers work by **running CLI tools as subprocesses** via
`CommandRunner`. They are CLI wrappers, not SDK clients. This means:
- The agent CLI tool must be installed on the system
- Communication is via stdin (prompt) / stdout (streaming JSON)
- No in-process state sharing (clean isolation)
- Stats parsing depends on the CLI's output format

#### Claude Provider (`agent/providers/claude.rb`)

**Command**: `claude -p --verbose --output-format stream-json [--model MODEL]
[--system-prompt PROMPT] [--append-system-prompt PROMPT] [--fork-session
--resume SESSION] [--dangerously-skip-permissions]`

Prompt is sent via stdin. Output is parsed line-by-line as JSON using a typed
message hierarchy (`Message`, `AssistantMessage`, `ResultMessage`,
`ToolUseMessage`, etc.). The final response text, session ID, and stats are
extracted from a `ResultMessage`.

**Multi-prompt**: First prompt uses `fork_session: true` to create an
independent fork; subsequent prompts use `fork_session: false` to continue in
the same forked session. Stats are merged across invocations.

#### Pi Provider (`agent/providers/pi.rb`)

**Command**: `pi --mode json -p [--model MODEL] [--fork SESSION | --no-session]`

Uses event-based message types (`session`, `turn_start`, `message_update`,
`message_end`, `tool_execution_start/end`, `agent_end`) instead of Claude's
typed message classes. Stats are accumulated manually across streaming events.

**Key differences from Claude**:

| Aspect | Claude | Pi |
|---|---|---|
| Output format | `--output-format stream-json` | `--mode json` |
| Session fork | `--fork-session --resume ID` | `--fork ID` |
| No session | (no flag) | `--no-session` |
| Permissions | `--dangerously-skip-permissions` | (not supported) |
| Stats | Single ResultMessage | Manual accumulation across events |
| Text streaming | From ResultMessage | Via `text_delta` / `text_end` events |

### Execute Behavior

1. Lazily initialize provider based on `config.valid_provider!` (memoized in
   `@provider`) (`agent.rb`, lines 59–67)
2. Call `provider.invoke(input)` → returns provider-specific `Output` subclass
   (`agent.rb`, line 50)
3. Display stats and session ID if `show_stats?` is enabled (`agent.rb`,
   lines 51–52)
4. Return the Output

---

## 5. ruby Cog

**Source**: `lib/roast/cogs/ruby.rb`  
**Purpose**: A **no-op cog** that gives you a "naked" input block. All real work
happens in the input block; `execute` just passes the value through unchanged.

### Why It Exists

Every cog in Roast has an input block — a full Ruby execution context where you
can write arbitrary code. For `cmd`, `chat`, and `agent`, the input block is
preparation for the cog's own action (running a command, calling an LLM, etc.).
But sometimes you want to write a chunk of Ruby logic — compute something,
transform data, set up files — without needing a "real" cog underneath.

Without the `ruby` cog, you'd need to create a `chat` cog with a dummy prompt
like "repeat this string verbatim" just to get an input block to run your code
in. That would be cumbersome and wasteful. The `ruby` cog was created to provide
a **clean input block with no underlying action**. It's named `ruby` (not
`no-op`) because from the workflow author's perspective, it _looks like_ writing
Ruby code that Roast executes — even though technically the execution is
happening entirely in the input context.

> **Key mental model**: For `cmd`/`chat`/`agent`, the input block is
> preparation and `execute(input)` is action. For `ruby`, the input block IS
> the action and `execute(input)` is just bookkeeping.

### Config (`Ruby::Config`)

Empty subclass of `Cog::Config`. Inherits only the common options (§1).

### Input (`Ruby::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `value` | `untyped` | Conditional | `nil` |

**Validation** (`ruby.rb`, line 31): Raises `InvalidInputError` if `value` is
`nil` AND `coerce_ran?` is `false`. After coercion, `nil` is a legitimate value.

**Coercion** (`ruby.rb`, lines 43–46): Calls `super` (setting `@coerce_ran`),
then sets `@value = input_return_value` unconditionally. This means returning
anything from the input block — including `nil` — sets the value.

### Output (`Ruby::Output`)

| Field | Type | Description |
|---|---|---|
| `value` | `untyped` | The exact value passed through from input |

**Does NOT include** `WithJson`, `WithNumber`, or `WithText` — there is no
`raw_text` implementation.

#### Dynamic Method Dispatch (`method_missing`)

The Ruby cog's output uses a three-level dispatch priority (`ruby.rb`, lines
135–145):

1. **Value delegation**: If `value.respond_to?(name, false)` → delegates via
   `value.public_send(name, ...)`
2. **Hash key access**: If `value.is_a?(Hash) && value.key?(name)` → returns the
   hash value (or calls it if it's a `Proc`)
3. **Fallback**: `super` → standard `NoMethodError`

`respond_to_missing?` mirrors this logic for correct introspection.

#### Special Methods

| Method | Behavior |
|---|---|
| `[](key)` | Direct hash key access — bypasses method dispatch |
| `call(*args)` | If value is a `Proc`: calls it directly. If value is a `Hash`: first arg must be a `Symbol` key → fetches the `Proc` at that key → calls it |

### Execute Behavior

**This is a no-op by design.** The entire method body is:

```ruby
def execute(input)
  Output.new(input.value)     # ruby.rb, line 164
end
```

No transformation. No side effects. No LLM call. No shell command. The `ruby`
cog's `execute` exists solely to satisfy the framework's `Config → Input →
Execute → Output` lifecycle contract. All meaningful work is expected to happen
in the input block, with the result either set explicitly via `my.value = ...`
or returned as the block's return value (which gets coerced to `value`).

---

## 6. call System Cog

**Source**: `lib/roast/system_cogs/call.rb`  
**Purpose**: Invoke a named execution scope (defined with `execute(:name) { ... }`)
with a provided value and index.

### Config (`Call::Config`)

Empty subclass — no call-specific config options. Inherits only the common
options (§1).

### Params (`Call::Params`)

| Field | Type | Description |
|---|---|---|
| `run` | `Symbol` | The name of the execution scope to invoke |
| `name` | `Symbol?` | Optional cog name (auto-generated UUID if omitted) |

Set at declaration time in the `execute {}` block:
`call(:result, run: :my_scope) { ... }`

### Input (`Call::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `value` | `untyped` | Yes | `nil` |
| `index` | `Integer` | No | `0` |

**Validation** (`call.rb`, line 58): Raises if `value.nil?` and `coerce_ran?`
is `false`.

**Coercion** (`call.rb`, lines 65–67): Calls `super`, then sets `@value =
input_return_value` unless `@value.present?`.

⚠️ **`present?` pitfall**: If you explicitly set `value` to `false`, `""`, or
`[]`, the coercion will overwrite it with the block's return value.

### Output (`Call::Output`)

Wraps an `ExecutionManager` instance (stored in private `@execution_manager`).

**Primary access**: Use `from()` in the CogInputContext (see below).

### Manager Module (`Call::Manager`)

Mixed into `ExecutionManager`. Creates the system cog with an `on_execute`
callback that:

1. Creates a new `ExecutionManager` for the named scope, passing
   `scope_value: input.value` and `scope_index: input.index` (`call.rb`,
   lines 96–104)
2. Calls `em.prepare!` then `em.run!` (`call.rb`, lines 105–106)
3. Catches both `ControlFlow::Next` and `ControlFlow::Break` identically —
   ends the inner execution early and returns normally (`call.rb`, line 108)
4. Returns `Output.new(em)` (`call.rb`, line 113)

### InputContext Module (`Call::InputContext`)

Defines the `from()` method on `CogInputContext`:

```ruby
from(call_cog_output)           # Returns the scope's final_output directly
from(call_cog_output) { ... }   # Evaluates block in the inner scope's CogInputContext
```

With a block, the block receives `(final_output, scope_value, scope_index)` and
is evaluated via `instance_exec` in the inner scope's `CogInputContext` —
meaning you can access inner-scope cog outputs:

```ruby
from(call!(:my_call)) { cmd!(:inner_step).text }
```

**Implementation**: Uses `instance_variable_get(:@execution_manager)` to extract
the EM from the output — a pragmatic encapsulation bypass (`call.rb`, line 148).
The `scope_value` is `deep_dup`'d before being passed to the block (`call.rb`,
line 152).

---

## 7. map System Cog

**Source**: `lib/roast/system_cogs/map.rb`  
**Purpose**: Execute a named scope once per item in a collection, either serially
or in parallel.

### Config (`Map::Config`)

| Method | Stored Value | `valid_parallel!` Returns | Behavior |
|---|---|---|---|
| *(default — no call)* | absent | `1` | **Serial** |
| `parallel(5)` | `5` | `5` | 5 concurrent iterations |
| `parallel(0)` | `nil` | `nil` | Unlimited concurrency |
| `parallel!` | `nil` | `nil` | Unlimited concurrency |
| `no_parallel!` | `1` | `1` | Serial |

**Query**: `valid_parallel!` → `@values.fetch(:parallel, 1)`. Returns `nil` for
unlimited, `Integer` for limited. Raises `InvalidConfigError` if negative.
(`map.rb`, lines 86–92)

**`validate!`**: Calls `valid_parallel!` on prepare (`map.rb`, line 71).

### Params (`Map::Params`)

| Field | Type | Description |
|---|---|---|
| `run` | `Symbol` | The named scope to invoke per item |
| `name` | `Symbol?` | Optional cog name |

### Input (`Map::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `items` | `Array[untyped]` | Yes | `[]` |
| `initial_index` | `Integer` | No | `0` |

**Validation** (`map.rb`, lines 144–146): Raises if `items.nil?`. Also raises if
`items.empty?` and `coerce_ran?` is false (to allow intentionally empty
collections after coercion).

**Coercion** (`map.rb`, lines 155–159): If `@items` is not `present?`,
converts the return value: enumerable → `.to_a`, non-enumerable →
`Array.wrap(value)`.

### Output (`Map::Output`)

Wraps `Array[ExecutionManager?]` — `nil` entries represent iterations that did
not run (due to `break!`).

| Method | Returns | Notes |
|---|---|---|
| `iteration(index)` | `Call::Output` | Wraps single EM. Raises `MapIterationDidNotRunError` for nil |
| `iteration?(index)` | `bool` | Check if iteration ran |
| `first` | `Call::Output` | Alias for `iteration(0)` |
| `last` | `Call::Output` | Alias for `iteration(-1)` |

Supports negative indices (e.g., `iteration(-1)` for the last).

**Error**: `MapIterationDidNotRunError < MapOutputAccessError < Roast::Error`

### Manager Module (`Map::Manager`)

Mixed into `ExecutionManager`. Dispatches to serial or parallel based on
`valid_parallel!`:

#### Serial Execution (`map.rb`, lines 288–302)

```
items.each_with_index → create EM → prepare! → run!
  rescue Next → continue to next item
  rescue Break → stop iterating
nil-fill unexecuted slots in output array
```

**Key detail**: `ems.fill(nil, ems.length, items.length - ems.length)` ensures
the output array always matches the input items count.

#### Parallel Execution (`map.rb`, lines 306–338)

```
Async::Barrier.new + Async::Semaphore.new(limit) if limited
items.map.with_index → (semaphore || barrier).async(finished: false) → create EM → prepare! → run!
  rescue Next → continue (EM still stored)
barrier.wait → task.wait
  rescue Break → barrier.stop
  rescue StandardError → barrier.stop; re-raise
Reconstruct ordered Array from Hash
```

**Critical implementation details**:
1. **Hash storage**: `ems = {}` keyed by integer index — avoids concurrent Array
   mutation issues. Reconstructed to Array via
   `(0...items.length).map { |idx| ems[idx] }` (`map.rb`, line 334)
2. **`finished: false`**: Prevents auto-completion before barrier management
   (`map.rb`, line 311)
3. **Break in parallel**: Caught during `barrier.wait`, stops all concurrent
   tasks (`map.rb`, lines 326–328)
4. **Ensure cleanup**: `barrier&.stop` always called (`map.rb`, line 337)
5. **Ordering guaranteed**: Results are always in input order regardless of
   completion order

### InputContext Module (`Map::InputContext`)

#### `collect(map_output, &block)`

Without block: `ems.map { |em| em&.final_output }` — `nil` for unexecuted
iterations.

With block: Evaluates block in each iteration's `CogInputContext` via
`instance_exec(final_output, scope_value, scope_index, &block)`. `nil`
iterations produce `nil` in the output array. (`map.rb`, lines 375–388)

#### `reduce(map_output, initial_value = nil, &block)`

Folds over `ems.compact` (skips nil iterations entirely). Block receives
`(accumulator, final_output, scope_value, scope_index)` and is evaluated in
each iteration's `CogInputContext`. (`map.rb`, lines 426–446)

⚠️ **Nil-preservation**: If the block returns `nil`, the accumulator is NOT
updated (`map.rb`, lines 438–443). This prevents accidental nil-overwrites but
means you **cannot intentionally set the accumulator to `nil`**.

---

## 8. repeat System Cog

**Source**: `lib/roast/system_cogs/repeat.rb`  
**Purpose**: Execute a named scope in a loop, feeding each iteration's output
as the next iteration's input. Terminated by `break!` or `max_iterations`.

### Config (`Repeat::Config`)

Empty subclass — no repeat-specific config options. Inherits only the common
options (§1).

### Params (`Repeat::Params`)

| Field | Type | Description |
|---|---|---|
| `run` | `Symbol` | The named scope to invoke for each iteration |
| `name` | `Symbol?` | Optional cog name |

### Input (`Repeat::Input`)

| Field | Type | Required | Default |
|---|---|---|---|
| `value` | `untyped` | Yes | `nil` |
| `index` | `Integer` | No | `0` |
| `max_iterations` | `Integer?` | No | `nil` (no limit) |

**Validation** (`repeat.rb`, lines 71–73): Raises if `value.nil?` and
`coerce_ran?` is false. Raises if `max_iterations` is present and `< 1`.

**Coercion** (`repeat.rb`, lines 81–83): Calls `super`, then sets `@value`
unless `@value.present?`.

### Output (`Repeat::Output`)

Wraps `Array[ExecutionManager]` — unlike Map, there are **no nil entries**
because only completed iterations are stored.

| Method | Returns | Description |
|---|---|---|
| `value` | `untyped` | Last iteration's `final_output` (`@execution_managers.last&.final_output`) |
| `iteration(index)` | `Call::Output` | Wraps specific iteration's EM |
| `first` | `Call::Output` | Alias for `iteration(0)` |
| `last` | `Call::Output` | Alias for `iteration(-1)` |
| `results` | `Map::Output` | **Bridge to Map's collect/reduce** |

The `results` method is the key design pattern: it wraps the iteration EMs in a
`Map::Output`, enabling reuse of `collect` and `reduce`:

```ruby
collect(repeat!(:loop).results)                  # All iteration outputs as array
reduce(repeat!(:loop).results, 0) { |sum, out| sum + out.integer }  # Aggregate
```

### Manager Module (`Repeat::Manager`)

Mixed into `ExecutionManager`. Creates the system cog with an `on_execute`
callback that runs a Ruby `loop`:

```
scope_value = input.value.deep_dup          # initial deep copy
loop do
  create EM(scope: params.run, scope_value:, scope_index: ems.length)
  em.prepare! → em.run!
  scope_value = em.final_output             # CHAIN: output feeds next iteration
  break if max_iterations reached
rescue ControlFlow::Break → break
end
Output.new(ems)
```

(`repeat.rb`, lines 208–236)

**Critical details**:
1. **Output chaining**: `scope_value = em.final_output` — the output of
   iteration N becomes the input of iteration N+1 (`repeat.rb`, line 228)
2. **Initial deep copy**: `input.value.deep_dup` prevents mutation leakage
   (`repeat.rb`, line 214)
3. **Auto-incrementing index**: `scope_index: ems.length` → 0, 1, 2, ...
   (`repeat.rb`, line 224)
4. **max_iterations check after execution**: The iteration runs before the limit
   check, so `max_iterations: 1` still executes one iteration (`repeat.rb`,
   line 229)
5. **Only `Break` is caught**: `ControlFlow::Next` is NOT caught by the Repeat
   manager (`repeat.rb`, lines 230–232)

⚠️ **Known bug**: Since Repeat only catches `Break`, a synchronous cog calling
`next!` inside a repeat loop causes the `Next` exception to escape the repeat
entirely and propagate to the parent scope. See
[07-control-flow-reference.md](07-control-flow-reference.md) for details.

### How Next Works in Repeat (Subtle)

When `next!` is called inside a repeat iteration:
1. The inner EM's `wait_for_task_with_exception_handling` catches `Next` →
   stops barrier → no re-raise (for async cogs)
2. For sync cogs, `Next` propagates out of `em.run!` and escapes the repeat
   loop entirely (bug)
3. For async cogs, `em.run!` completes normally; `compute_final_output` runs;
   `scope_value = em.final_output` picks up whatever was computed — the
   "skipped" iteration still counts and feeds into the next iteration

### Comparison: Map vs Repeat

| Aspect | Map | Repeat |
|---|---|---|
| Item count | Predetermined (`items.length`) | Unbounded (until `break!` / `max_iterations`) |
| Nil entries | Yes (for break'd iterations) | No — only completed iterations stored |
| `iteration()` on nil | Raises `MapIterationDidNotRunError` | N/A |
| Output chaining | No (each iteration gets original item) | Yes (output N → input N+1) |
| `value` accessor | N/A | Returns last iteration's final_output |
| `results` bridge | N/A | Returns `Map::Output` for collect/reduce |

---

## 9. Config Merge Cascade

**Source**: `lib/roast/config_manager.rb`, `config_for` method (lines 44–59)

When a cog runs, its configuration is assembled by merging four layers. Each
layer overrides the previous via `Config#merge` (Hash merge, right-side wins):

```
Step 1: Start with cog-type Config, seeded with global @values (deep_dup'd)
Step 2: Merge general config for this cog type     (e.g., config { agent { ... } })
Step 3: Merge each regexp-matched config            (e.g., config { agent(/review/) { ... } })
Step 4: Merge name-specific config                  (e.g., config { agent(:analyze) { ... } })
Step 5: Call validate! on the merged result
```

**Detail on Step 1**: The global config's `@values` hash is extracted via
`instance_variable_get(:@values)` and deep_dup'd into a new cog-specific Config
instance (`config_manager.rb`, line 48). This is a "back-door" access pattern —
`ConfigManager` reaches into `Cog::Config`'s internal storage rather than using
public API, because global values may contain keys that are not declared on the
specific cog's Config subclass.

**Regexp matching** (`config_manager.rb`, lines 50–52): All regexp-scoped
configs for the cog class are checked against the cog's name via
`pattern.match?(name.to_s)`. Multiple patterns can match — each matching
config is merged in iteration order.

**Reopenable config blocks**: Multiple `config {}` blocks in a workflow are
collected and evaluated sequentially during `prepare!`. They all mutate the same
config objects, so later blocks override earlier ones within the same scope level.

---

## 10. Output Mixin Modules

**Source**: `lib/roast/cog/output.rb`

All three modules depend on the implementing class providing a private
`raw_text` method that returns `String?`.

### WithText

| Method | Returns | Behavior |
|---|---|---|
| `text` | `String` | `raw_text.strip` |
| `lines` | `Array[String]` | `raw_text.lines.map(&:strip)` |

### WithJson

| Method | Returns | Behavior |
|---|---|---|
| `json!` | `Hash[Symbol, untyped]` | Parse JSON; raise `JSON::ParserError` on failure |
| `json` | `Hash[Symbol, untyped]?` | Parse JSON; return `nil` on failure |

**All JSON keys are symbolized** (`symbolize_names: true`).

**Empty input**: Returns `{}` if input is `nil` or blank (`output.rb`, line 23).

**Results are memoized** in `@json` (`output.rb`, line 25).

**Candidate extraction priority** (`output.rb`, lines 68–75):

| Priority | Source | Scanning Order |
|---|---|---|
| 1 | Entire input string (stripped) | — |
| 2 | `` ```json `` code blocks | **Last first** |
| 3 | `` ``` `` code blocks (no language) | **Last first** |
| 4 | `` ```<type> `` code blocks (any non-json language) | **Last first** |
| 5 | JSON-like `{}`/`[]` blocks extracted from text | **Longest first** |

**Why last-first?** LLMs tend to place their final, refined answer in the last
code block. Scanning last-first finds the most relevant answer faster.

Each candidate is tried with `JSON.parse`; the first successful parse wins. If
all fail, raises `JSON::ParserError`.

### WithNumber

| Method | Returns | Behavior |
|---|---|---|
| `float!` | `Float` | Parse number; raise `ArgumentError` on failure |
| `float` | `Float?` | Parse number; return `nil` on failure |
| `integer!` | `Integer` | `float!.round` |
| `integer` | `Integer?` | `integer!` or `nil` on failure |

**Results are memoized** in `@float` and `@integer`.

**Candidate extraction priority** (`output.rb`, lines 230–249):

| Priority | Source | Scanning Order |
|---|---|---|
| 1 | Entire string (stripped) | — |
| 2 | Each line | **Bottom-up** (last line first) |
| 3 | Number-pattern matches within each line | **Bottom-up, rightmost first** |

**Normalization** (`output.rb`, lines 255–261): Strips currency symbols
(`$¢£€¥`), commas, underscores, and spaces. Validates against the pattern:
`-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?`

Very permissive: handles `1,234.56`, `€1.23`, `1_000`, scientific notation.

### Design Pattern

Both JSON and number parsing use a **"generate candidates → try each → first
success wins"** strategy. This is intentionally resilient to messy LLM output
where actual data may be buried in surrounding prose or code blocks. The
framework absorbs this parsing complexity so workflow authors don't have to.

---

## 11. Boolean Default Patterns

The codebase uses **four distinct patterns** for boolean config defaults. This
inconsistency is a known artifact of organic development. Understanding the
patterns is essential for both reading existing code and writing custom cogs.

| Pattern | Example | Default When Unset | Correct for Falsy? |
|---|---|---|---|
| `@values.fetch(:key, true)` | `abort_on_failure?` | `true` | ✅ Yes |
| `@values.fetch(:key, false)` | `show_prompt?` (chat, agent) | `false` | ✅ Yes |
| `!!@values[:key]` | `async?` | `false` | ✅ Yes |
| `@values[:key] != false` | `fail_on_error?` (cmd) | `true` | ⚠️ Only `false` |

The `fetch` pattern is the clearest and most correct — it handles all falsy
values correctly. The `!!` pattern also works (nil → false). The `!= false`
pattern is correct for its specific use (only `false` is the negative case,
`nil` means "not set, use default true"), but it's the least obvious.

The `field` macro's `@values[key] || default.deep_dup` pattern is **incorrect
for booleans** — see §1 for the pitfall.

---

## Where to Go Next

- **[01-architecture-overview.md](01-architecture-overview.md)** — Foundational
  mental model (read first if you haven't)
- **[02-dsl-users-guide.md](02-dsl-users-guide.md)** — How to write workflows
  using these cogs (practical usage)
- **[06-metaprogramming-map.md](06-metaprogramming-map.md)** — How the config,
  execute, and input methods for each cog type are dynamically defined
- **[07-control-flow-reference.md](07-control-flow-reference.md)** — The
  complete exception propagation matrix across all cog types
- **[10-writing-custom-cogs.md](10-writing-custom-cogs.md)** — How to create
  your own cog types
