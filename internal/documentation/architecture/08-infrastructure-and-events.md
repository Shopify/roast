# Document 8: Infrastructure & Events

The infrastructure layer solves a fundamental problem in concurrent workflow execution:
**how to correctly attribute output from parallel fibers to the right cog/scope in the
workflow hierarchy**. It does this through a 4-stage event pipeline, fiber-local path
tracking, global IO interception, and a two-layer logging design.

---

## 1. The 4-Stage Event Pipeline

```
┌──────────────────────┐
│      PRODUCERS       │
│  TaskContext (.begin) │
│  Roast::Log (.info)  │
│  OutputRouter (.write)│
└─────────┬────────────┘
          │ Event << { key: value }
          ▼
┌──────────────────────┐
│       EVENT          │
│  path + payload + time│
└─────────┬────────────┘
          │ EventMonitor.accept(event)
          ▼
┌──────────────────────┐
│   EVENT MONITOR      │
│  Async::Queue consumer│
│  handle_#{type}_event │
└─────────┬────────────┘
          │ Roast::Log.logger.add(...)
          ▼
┌──────────────────────┐
│      $stderr         │
│  (via Logger backend) │
└──────────────────────┘
```

### Why This Exists

In a parallel map with 10 fibers all running cmd cogs simultaneously, each fiber's
stdout/stderr must be attributed to the correct `{:files}[3] -> cmd(:lint)` path.
Without this pipeline, output from concurrent fibers would interleave without
attribution, making parallel workflows undebuggable.

### Three Producer Categories

| Producer | Events Created | Source |
|----------|---------------|--------|
| **TaskContext** | `{begin: PathElement}`, `{end: PathElement}` | `lib/roast/task_context.rb` lines 28–41 |
| **Roast::Log** | `{debug: msg}`, `{info: msg}`, `{warn: msg}`, `{error: msg}`, `{fatal: msg}`, `{unknown: msg}` | `lib/roast/log.rb` lines 35–62 |
| **OutputRouter** | `{stdout: str}`, `{stderr: str}` | `lib/roast/output_router.rb` lines 52–63 |

All events enter the pipeline through exactly ONE entry point: `Event << { key: value }`
(line 8 of `lib/roast/event.rb`).

---

## 2. Event Class

**Source**: `lib/roast/event.rb` (75 lines)

### Structure

```ruby
class Event
  attr_reader :path      # Array[TaskContext::PathElement] — snapshot of producer's path
  attr_reader :payload   # Hash[Symbol, untyped] — the event data
  attr_reader :time      # Time — when the event was CREATED (not processed)
end
```

### The Universal Emitter (line 8)

```ruby
def self.<<(event)
  EventMonitor.accept(Event.new(TaskContext.path, event))
end
```

This is the ONLY way events enter the pipeline. `TaskContext.path` returns a `deep_dup`
of the current fiber's path, capturing the exact execution position at creation time.

### Type Detection (lines 48–52)

Key-intersection based, with log types taking priority:

```ruby
def type
  return :log if (LOG_TYPE_KEYS & @payload.keys).present?
  (OTHER_TYPE_KEYS & @payload.keys).first || :unknown
end
```

**Priority rule**: If a payload contains BOTH a log key and an other key (e.g.,
`{info: "msg", begin: element}`), the event type is `:log`. This prioritization
ensures that log messages are never misrouted.

**Type keys**:
- `LOG_TYPE_KEYS`: `[:fatal, :error, :warn, :info, :debug, :unknown]`
- `OTHER_TYPE_KEYS`: `[:begin, :end, :stdout, :stderr]`

### Severity Mapping (lines 55–65)

```ruby
def log_severity
  severity = case type
  when :log
    (LOG_TYPE_KEYS & @payload.keys).first || :unknown
  when :stderr
    :warn
  else
    :info
  end
  Logger::Severity.const_get(:LEVELS)[severity.to_s]
end
```

- Log events → severity from the key name (`:debug`=0, `:info`=1, `:warn`=2, etc.)
- stderr events → always `:warn`
- Everything else → `:info`

### Delegate Pattern (line 38)

```ruby
delegate :[], :key?, :keys, to: :payload
```

Events can be treated like hashes: `event[:begin]`, `event.key?(:stdout)`.

---

## 3. EventMonitor

**Source**: `lib/roast/event_monitor.rb` (162 lines)

A **singleton module** (`extend self`) with two operational modes. This dual-mode
design is critical for testability.

### Running Mode (during workflow execution)

**Startup** (`start!`, line 24):
1. Raises `EventMonitorAlreadyStartedError` if already running
2. Calls `OutputRouter.enable!` — starts intercepting IO
3. Creates a new `Async::Queue`
4. Spawns a `transient: true` Async task as the consumer fiber
5. Consumer calls `OutputRouter.mark_as_output_fiber!` (prevents recursion — see §4)
6. Consumer loops: `@queue.pop` → `handle_event` → repeat until `nil`

**Shutdown** (`stop!`, line 41):
1. Raises `EventMonitorNotRunningError` unless running
2. Calls `OutputRouter.disable!` — stops intercepting IO
3. Closes the queue (causes consumer to receive `nil` → break)
4. `@task.wait` — blocks until consumer drains remaining events

**Reset** (`reset!`, line 51):
- Force-close without waiting. Used in tests to avoid hangs.

### Not-Running Mode (before/after workflow, during tests)

```ruby
def accept(event)
  if running?
    @queue.push(event)
  else
    handle_event(event)  # synchronous fallback
  end
end
```

When the monitor isn't running, events are handled synchronously in the current fiber.
This is why `Roast::Log.info` works even outside a workflow context (e.g., in tests,
in CLI setup code).

### Handler Dispatch (lines 69–78)

Dynamic dispatch via `send`:

```ruby
def handle_event(event)
  with_stubbed_class_method_returning(Time, :now, event.time) do
    OutputRouter.mark_as_output_fiber!
    handler_method_name = "handle_#{event.type}_event".to_sym
    if respond_to?(handler_method_name, true)
      send(handler_method_name, event)
    else
      handle_unknown_event(event)
    end
  end
end
```

### Handler Methods

| Handler | Trigger | Behavior |
|---------|---------|----------|
| `handle_begin_event` | `:begin` | Logs "Starting" for cog begins; "🔥🔥🔥 Workflow Starting" for top-level EM |
| `handle_begin_workflow_event` | first `:begin` | Debug dump of WorkflowContext (targets, args, kwargs, tmpdir, workflow_dir, pwd) |
| `handle_end_event` | `:end` | Logs "Complete" for cog ends; "🔥🔥🔥 Workflow Complete" for top-level EM |
| `handle_log_event` | any log key | `Log.logger.add(severity, "path message")` |
| `handle_stdout_event` | `:stdout` | `Log.logger.info { "path ❯ content" }` (single chevron) |
| `handle_stderr_event` | `:stderr` | `Log.logger.warn { "path ❯❯ content" }` (double chevron) |
| `handle_unknown_event` | unrecognized | `Log.logger.unknown(event.inspect)` |

### Time Preservation (line 70)

```ruby
with_stubbed_class_method_returning(Time, :now, event.time) do
  # ... handle event ...
end
```

This temporarily stubs `Time.now` to return the event's **creation time** (when the
producer fiber emitted it), not the **processing time** (when the consumer fiber handles
it). Without this, all events in a parallel burst would show the same "processed at"
timestamp instead of their actual creation times.

**Implementation** (lines 151–161): Saves the original singleton method, replaces with
a proc returning the fixed value, calls the block, then restores the original in `ensure`.

### Path Formatting (lines 138–148)

```ruby
def format_path(event)
  event.path.map do |element|
    cog = element.cog
    execution_manager = element.execution_manager
    if cog.present?
      "#{cog.type}#{cog.anonymous? ? "" : "(:#{cog.name})"}"
    elsif execution_manager&.scope
      "{:#{execution_manager.scope}}[#{execution_manager.scope_index}]"
    end
  end.compact.join(" -> ")
end
```

Produces human-readable paths:
- `{:files}[0] -> agent(:analyze)` — scoped EM iteration 0, agent cog named "analyze"
- `cmd(:build)` — named cog at top level
- `cmd` — anonymous cog (no name suffix)
- ` ` (empty string) — top-level EM with no scope (compacted out by `.compact`)

### Error Hierarchy

```
StandardError
  └── EventMonitorError                     (line 9)
        ├── EventMonitorAlreadyStartedError (line 11)
        └── EventMonitorNotRunningError     (line 13)
```

**Important**: NOT under `Roast::Error`. A `rescue Roast::Error` will NOT catch these.
Same isolation pattern as `CommandRunnerError`.

---

## 4. OutputRouter

**Source**: `lib/roast/output_router.rb` (76 lines)

### Purpose

Intercept `$stdout.write` and `$stderr.write` calls from non-output fibers and route
them through the Event system for proper path attribution. Without this, any gem or
library that writes to stdout/stderr directly would produce unattributed output.

### Activation (`enable!`, line 12)

```ruby
def self.enable!
  return false if enabled?
  activate($stdout, :stdout)
  activate($stderr, :stderr)
  mark_as_output_fiber!
  true
end
```

The `activate` method (line 49):
1. `alias_method :write_without_roast, :write` — saves the original write
2. `define_singleton_method(:write)` — installs the routing interceptor
3. The interceptor checks `router.output_fiber?` to decide routing

### Deactivation (`disable!`, line 22)

The `deactivate` method (line 68):
```ruby
def deactivate(stream)
  sc = stream.singleton_class
  sc.send(:remove_method, :write)               # remove interceptor
  sc.send(:alias_method, :write, WRITE_WITHOUT_ROAST)  # restore original
  sc.send(:remove_method, WRITE_WITHOUT_ROAST)  # clean up alias
end
```

A clean three-step restore that leaves no traces on the singleton class.

### Routing Logic (lines 52–63)

```ruby
stream.define_singleton_method(:write) do |*args|
  if router.output_fiber?
    self.send(WRITE_WITHOUT_ROAST, *args)  # direct pass-through
  else
    str = args.map(&:to_s).join
    Event << case name
    when :stdout then { stdout: str }
    when :stderr then { stderr: str }
    else { unknown: str }
    end
  end
end
```

**Decision rule**: If the current fiber IS the output fiber → write directly (no event).
If it's any other fiber → create an Event so the write gets attributed to the correct
path in the workflow hierarchy.

### Fiber Identity (lines 37–43)

```ruby
def self.output_fiber?
  @output_fiber == Fiber.current
end

def self.mark_as_output_fiber!
  @output_fiber = Fiber.current
end
```

Only ONE fiber is the output fiber at a time. The EventMonitor's consumer fiber calls
`mark_as_output_fiber!` both at startup (line 30) and within each `handle_event` call
(line 71). This ensures that when the consumer writes to $stderr via `Log.logger`, those
writes bypass the interceptor and go directly to the real IO.

### The WRITE_WITHOUT_ROAST Escape Hatch

```ruby
WRITE_WITHOUT_ROAST = :write_without_roast
```

Any code that needs to bypass routing can call:
```ruby
$stdout.send(OutputRouter::WRITE_WITHOUT_ROAST, "direct output")
```

### ⚠️ The Circular Flow (Critical)

This is the most subtle interaction in the infrastructure layer:

```
Roast::Log.info("msg")
  → Event << { info: "msg" }
    → EventMonitor.accept(event)
      → @queue.push(event)
        ... async queue transfer ...
      → handle_event(event)
        → handle_log_event(event)
          → Roast::Log.logger.add(severity, "msg")
            → Logger writes to $stderr
              → OutputRouter.write intercepts
                → output_fiber? == true  ← BECAUSE we're in the EM consumer
                  → write_without_roast("msg")  ← breaks the cycle
```

If `output_fiber?` didn't return `true` for the consumer fiber, the Logger's write
to $stderr would create another Event, which would be queued, which would be handled,
which would write to $stderr again → **infinite recursion**.

The distinction between:
- `Roast::Log.info("msg")` — public API, creates Events, goes through the pipeline
- `Roast::Log.logger.add(severity, "msg")` — internal backend, writes directly to IO

is **CRITICAL**. Calling `Roast::Log.logger.info("msg")` from application code would
bypass event attribution entirely.

### ⚠️ Global State Modification

`$stdout` and `$stderr` are process-global. OutputRouter patches their singleton classes.
If `disable!` is not called (e.g., test crashes), subsequent code could break.
This is why `EventMonitor.reset!` exists and is called in test teardown.

---

## 5. TaskContext

**Source**: `lib/roast/task_context.rb` (53 lines)

A **singleton module** (`extend self`) that maintains per-fiber execution path stacks
using Ruby 3.2+ fiber-local variables.

### PathElement (lines 8–19)

```ruby
class PathElement
  attr_reader :cog              # Cog?
  attr_reader :execution_manager # ExecutionManager?

  def initialize(cog: nil, execution_manager: nil)
    @cog = cog
    @execution_manager = execution_manager
  end
end
```

One field or the other is set, never both. A path is a sequence of alternating EM and
Cog elements representing the current position in the workflow hierarchy.

### Fiber[:path] Storage

Ruby 3.2+ fiber-local variables: `Fiber[:path]` is an Array unique to each fiber.

**Creation semantics**:
- `Fiber.new(storage: {})` creates a child fiber with an isolated empty path
- Child fibers without explicit `storage:` inherit the parent's storage reference
- Map parallel creates fibers with `storage: {}` for full isolation

### Lifecycle Methods

**`begin_cog(cog)`** (line 28):
```ruby
def begin_cog(cog)
  begin_element(PathElement.new(cog:))
end
```

**`begin_execution_manager(em)`** (line 33):
```ruby
def begin_execution_manager(execution_manager)
  begin_element(PathElement.new(execution_manager:))
end
```

**`end`** (line 38):
```ruby
def end
  Event << { end: Fiber[:path]&.last }
  el = Fiber[:path]&.pop
  [el, path]
end
```

Returns `[popped_element, remaining_path_snapshot]`.

### Path Isolation (line 48) — Critical Detail

```ruby
def begin_element(element)
  Fiber[:path] = (Fiber[:path] || []) + [element]
  Event << { begin: element }
  path
end
```

The expression `(Fiber[:path] || []) + [element]` creates a **NEW array**. This is
essential because child fibers that inherit the parent's `Fiber[:path]` reference would
otherwise see mutations to each other's paths. By replacing the array entirely (not
pushing to it), each fiber's subsequent path changes are isolated.

### Path Deep-Dup (line 23)

```ruby
def path
  Fiber[:path]&.deep_dup || []
end
```

Events get a snapshot of the path, not a live reference. This prevents the path from
changing between when the event is created and when the EventMonitor processes it
(which may be milliseconds later in a concurrent workflow).

### Integration Points

- `Cog.run!` line 76: `TaskContext.begin_cog(self)` / line 100: `TaskContext.end`
- `ExecutionManager.run!` line 94: `TaskContext.begin_execution_manager(self)` / line 113: `TaskContext.end`

---

## 6. Logging

**Source**: `lib/roast/log.rb` (99 lines), `lib/roast/log_formatter.rb` (55 lines)

### The Two-Layer Design

This is a common source of confusion. There are TWO ways to produce log output:

| Layer | API | What It Does | When to Use |
|-------|-----|-------------|-------------|
| **Public** | `Roast::Log.info("msg")` | Creates an Event, goes through the pipeline | Application code, cog implementations |
| **Internal** | `Roast::Log.logger.info("msg")` | Writes directly to the Logger's IO device | EventMonitor handlers ONLY |

Calling `Roast::Log.logger.info` from application code bypasses:
- Path attribution (no fiber context captured)
- Async queue ordering (writes immediately, not in event order)
- Time preservation (uses wall-clock time, not event creation time)

### Roast::Log Module (`lib/roast/log.rb`)

**Public methods** (lines 35–62): `debug`, `info`, `warn`, `error`, `fatal`, `unknown`
— all simply emit Events:
```ruby
def info(message)
  Roast::Event << { info: message }
end
```

**Logger accessor** (line 65): `logger` — memoized stdlib Logger instance writing to $stderr.

**Configuration**:
- `ROAST_LOG_LEVEL` env var (line 94) — sets minimum level; default `INFO`
- `attr_writer :logger` (line 33) — replace with any Logger-compatible object (e.g., `Rails.logger`)
- `reset!` (line 70) — clears memoized logger (used in tests)

**TTY detection** (line 75):
```ruby
def tty?
  return false unless @logger
  logdev = @logger.instance_variable_get(:@logdev)&.dev
  logdev&.respond_to?(:isatty) && logdev&.isatty
end
```

### LogFormatter (`lib/roast/log_formatter.rb`)

Two output formats:

**TTY format** (compact):
```
• I, Starting agent(:analyze)
```

**Non-TTY format** (full):
```
I, [2026-01-01T12:00:00.000000] INFO -- Starting agent(:analyze)
```

**ANSI colorization** (lines 29–44):
| Content | Color |
|---------|-------|
| Lines containing `❯❯` (stderr) | Yellow |
| Lines containing `❯` (stdout) | Default (no extra color) |
| ERROR, FATAL | Red |
| WARN | Orange (`#FF8C00`) |
| INFO | Bright |
| DEBUG | Faint |

Uses the `Rainbow` gem with TTY-awareness (`@rainbow.enabled = tty`).

**`msg2str`** (lines 46–54): Strips whitespace from String messages before calling
`super` (parent Logger::Formatter behavior).

---

## 7. CLI & Invocation

**Source**: `lib/roast/cli.rb` (119 lines)

### Command Parsing Flow

```
argv = ["my_workflow.rb", "target1", "--", "--dry-run", "--model=gpt-4"]
         │                                      │
         ├─ split_at_separator ─────────────────┤
         │                                      │
         ▼                                      ▼
roast_args = ["my_workflow.rb", "target1"]   extra_args = ["--dry-run", "--model=gpt-4"]
         │                                      │
         ├─ OptionParser (-h/--help only) ──────│
         │                                      │
         ▼                                      ▼
command dispatch                     parse_custom_workflow_args
         │                                      │
         ▼                                      ▼
resolve_workflow_path              args: [:dry_run]  kwargs: {model: "gpt-4"}
```

### split_at_separator (lines 109–116)

Splits at `--` into `[roast_args, extra_args]`. If no `--`, extra_args is empty.

### Command Dispatch (lines 18–34)

Priority order:
1. `-h`/`--help` flag or `help` command → print help
2. `version` → print version string
3. `execute` → shift command, call `run_execute`
4. Implicit execute → if the command resolves to a file path, treat as workflow
5. Unknown → error message + help + exit(1)

### resolve_workflow_path (lines 65–76)

```ruby
def resolve_workflow_path(workflow_path)
  roast_working_directory = Pathname.new(File.expand_path(ENV["ROAST_WORKING_DIRECTORY"] || Dir.pwd))
  path = Pathname.new(workflow_path)
  resolved = if path.absolute? || path.exist?
    path
  else
    roast_working_directory / path
  end
  resolved.realpath
rescue Errno::ENOENT
  nil
end
```

Resolution rules:
- Absolute path or exists relative to cwd → use as-is
- Otherwise → join with `ROAST_WORKING_DIRECTORY` (defaulting to pwd)
- `.realpath` resolves symlinks
- Returns `nil` on file-not-found

### parse_custom_workflow_args (lines 79–91)

```ruby
def parse_custom_workflow_args(extra_args)
  args = []
  kwargs = {}
  extra_args.each do |arg|
    arg = arg.sub(/^--?(?=[^-])/, "")  # strip leading - or --
    if arg.include?("=")
      key, value = arg.split("=", 2)   # split at FIRST = only
      kwargs[key.to_sym] = value if key
    else
      args << arg.to_sym
    end
  end
  [args, kwargs]
end
```

**Conventions**:
- `--key=value` → kwarg `{key: "value"}` (value is always a String)
- `--flag` → arg `:flag` (Symbol)
- `--a=b=c` → `{a: "b=c"}` (splits at first `=` only)
- Leading `-` or `--` stripped by regex `/^--?(?=[^-])/`

### run_execute (lines 39–59)

The workflow entry point:
1. Validates workflow file argument present
2. Splits `args` into `workflow_path` and `targets` (remaining positionals)
3. Resolves path; errors on not-found
4. Parses custom args from `extra_args`
5. Constructs `WorkflowParams.new(targets, workflow_args, workflow_kwargs)`
6. `Dir.chdir(roast_working_directory)` — changes pwd for the duration
7. Calls `Workflow.from_file(real_workflow_path, workflow_params)`

### ROAST_WORKING_DIRECTORY Environment Variable

Used in TWO places:
- `resolve_workflow_path`: resolves relative paths against it
- `run_execute`: `Dir.chdir` into it for workflow execution

Default: `Dir.pwd` (current working directory).

---

## 8. WorkflowParams & WorkflowContext

### WorkflowParams (`lib/roast/workflow_params.rb`, 22 lines)

A simple value object:

```ruby
class WorkflowParams
  attr_reader :targets  # Array[String] — positional args after workflow path
  attr_reader :args     # Array[Symbol] — flag-style workflow args (--dry-run → :dry_run)
  attr_reader :kwargs   # Hash[Symbol, String] — key=value workflow args (--model=gpt-4 → {model: "gpt-4"})
end
```

**Important**: All kwarg values are Strings. No type coercion is performed.

### WorkflowContext (`lib/roast/workflow_context.rb`, 22 lines)

Immutable shared state constructed once per workflow invocation:

```ruby
class WorkflowContext
  attr_reader :params       # WorkflowParams — the parsed invocation parameters
  attr_reader :tmpdir       # String — Dir.mktmpdir (unique temp directory per run)
  attr_reader :workflow_dir # Pathname — dirname of the workflow .rb file
end
```

Constructed in `Workflow.from_file` and shared (by reference, never deep_dup'd) with
every ExecutionManager in the tree. WorkflowContext is the ONE exception to the
deep-copy-at-every-boundary rule — it's intentionally shared because it's immutable.

---

## 9. Complete Data Flow Example

A concrete trace of what happens when `cmd(:build)` writes to stdout in a parallel map:

```
1. cmd(:build) calls system("make")
   → make writes "Compiling..." to fd 1

2. Ruby's IO captures it; $stdout.write("Compiling...") is called

3. OutputRouter's interceptor fires (line 52)
   → output_fiber? == false (we're in a map worker fiber)
   → Event << { stdout: "Compiling..." }

4. Event.new(TaskContext.path, { stdout: "Compiling..." })
   → path = [{em: map_em, scope: :targets, index: 3}, {cog: build_cog}].deep_dup
   → time = Time.now (wall clock at creation)

5. EventMonitor.accept(event)
   → running? == true
   → @queue.push(event)

6. Consumer fiber pops event from queue (may be milliseconds later)
   → handle_event(event)
   → Time.now stubbed to event.time (step 4's timestamp)
   → mark_as_output_fiber! (ensure our writes go through)
   → handler = :handle_stdout_event

7. handle_stdout_event(event)
   → Roast::Log.logger.info { "{:targets}[3] -> cmd(:build) ❯ Compiling..." }

8. Logger calls $stderr.write(formatted_line)
   → OutputRouter intercepts
   → output_fiber? == true (we ARE the consumer fiber)
   → write_without_roast(formatted_line)  ← direct to terminal

9. User sees:
   • I, {:targets}[3] -> cmd(:build) ❯ Compiling...
```

---

## 10. Test Infrastructure Integration

### CaptureLogOutput Concern

Included in ALL test cases:
- **setup**: Creates `@logger_output` (StringIO), sets `Roast::Log.logger` to write there
- **teardown**: On test FAILURE, dumps captured output to $stderr (debugging aid), then calls `Roast::Log.reset!`

### EventMonitor in Tests

- Tests use `EventMonitor.reset!` (not `stop!`) in teardown — avoids needing an async context
- The not-running synchronous mode means events from `Roast::Log.info` still work in tests
- No Async reactor needed for simple cog unit tests

### original_streams_from_logger_output

A test helper that reconstructs original stdout/stderr from captured logger output by:
1. Parsing lines with `❯` marker as stdout
2. Parsing lines with `❯❯` marker as stderr
3. Treating non-log-prefix lines as continuations of the previous stream

---

## 11. Invariants for Contributors

1. **All events go through `Event <<`** — never call `EventMonitor.accept` directly
2. **Only EventMonitor handlers call `Log.logger.*`** — application code uses `Roast::Log.*`
3. **OutputRouter must be enabled/disabled symmetrically** — `enable!` without `disable!` corrupts $stdout/$stderr globally
4. **`mark_as_output_fiber!` must be called in the consumer** — forgetting this causes infinite recursion
5. **`TaskContext.path` returns a deep_dup** — events capture a snapshot, never a live reference
6. **`begin_element` creates a new array** — push would mutate shared references across fibers
7. **Time stubbing in handle_event is non-negotiable** — removing it breaks all timing accuracy in parallel workflows
8. **EventMonitor errors are NOT under Roast::Error** — `rescue Roast::Error` is intentionally insufficient for infrastructure failures
