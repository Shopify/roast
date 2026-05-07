# Document 11: Testing Guide

> **Audience**: Intern (primary), AI coding agents (secondary)
> **Purpose**: How to write and run tests for the Roast framework
> **Roast version**: 1.1.0

---

## 1. Test Stack

| Dependency | Role | Require |
|------------|------|---------|
| `minitest ~> 5.0` | Test framework | `minitest/autorun` |
| `active_support` | `ActiveSupport::TestCase` base class | `active_support/test_case` |
| `mocha` | Mocking/stubbing (auto-verifying) | `mocha/minitest` |
| `simplecov` | Code coverage | `simplecov` (loaded first) |
| `vcr` | HTTP interaction recording/replay | `vcr` |
| `webmock` | HTTP stubbing (VCR hook) | `webmock` |
| `minitest-rg` | Colorized test output | `minitest/rg` |
| `guard-minitest` | Watch-mode auto-runner (development) | Optional |

All test dependencies live in the Gemfile's development group. The entry point is `test/test_helper.rb`.

---

## 2. Running Tests

### Rake Tasks

| Command | What It Does |
|---------|--------------|
| `rake minitest_fast` | Run all tests, skipping those marked `slow_test!` |
| `rake minitest_all` | Run all tests including slow tests (`ROAST_RUN_SLOW_TESTS=true`) |
| `rake test` | Alias for `minitest_all` |
| `rake rubocop` | Run RuboCop with autocorrect |
| `rake rubocop_ci` | Run RuboCop without autocorrect (CI mode) |
| `rake sorbet` | Run Sorbet type checker (`bin/srb tc`) |
| `rake` (default) | Runs `sorbet` → `rubocop` → `minitest_fast` |
| `rake check` | Runs `sorbet` → `rubocop` only (no tests) |

**Source**: `Rakefile` (lines 1–56)

### Running Individual Tests

```bash
# Single test file
ruby -Itest -Ilib test/roast/cog_test.rb

# Single test by name
ruby -Itest -Ilib test/roast/cog_test.rb -n "test_started?_returns_false_before_execution"

# Pattern match
ruby -Itest -Ilib test/roast/cog_test.rb -n "/started/"
```

### Environment Variables

| Variable | Effect |
|----------|--------|
| `ROAST_RUN_SLOW_TESTS=1` | Enable slow tests (otherwise skipped) |
| `RECORD_VCR=true` | Record real HTTP responses (uses real API keys) |
| `PRESERVE_SANDBOX=1` | Keep functional test tmpdirs after test run |
| `CI=true` | Enable colorized output, dump stdout/stderr on functional tests |
| `ROAST_LOG_LEVEL` | Set logger level during test execution |

---

## 3. Test Directory Structure

```
test/
├── test_helper.rb                      # All shared infrastructure
├── support/
│   ├── improved_assertions.rb          # Custom assertion extensions
│   └── test_cog.rb                     # Reference test cog implementation
├── roast/                              # Unit tests (mirror lib/roast/)
│   ├── cog_test.rb                     # Roast::Cog base class
│   ├── cog/                            # Cog infrastructure
│   │   ├── config_test.rb
│   │   ├── input_test.rb
│   │   ├── output_test.rb
│   │   ├── registry_test.rb
│   │   ├── stack_test.rb
│   │   └── store_test.rb
│   ├── cogs/                           # Standard cogs
│   │   ├── cmd_test.rb
│   │   ├── ruby_test.rb
│   │   ├── chat/
│   │   │   ├── config_test.rb
│   │   │   ├── input_test.rb
│   │   │   ├── output_test.rb
│   │   │   └── session_test.rb
│   │   └── agent/
│   │       ├── config_test.rb
│   │       ├── input_test.rb
│   │       ├── output_test.rb
│   │       ├── provider_test.rb
│   │       ├── stats_test.rb
│   │       ├── usage_test.rb
│   │       └── providers/
│   │           ├── claude_test.rb
│   │           ├── claude/
│   │           │   ├── claude_invocation_test.rb
│   │           │   ├── message_test.rb
│   │           │   ├── tool_result_test.rb
│   │           │   ├── tool_use_test.rb
│   │           │   └── messages/ (9 message type tests)
│   │           ├── pi_test.rb
│   │           └── pi/
│   │               ├── pi_invocation_test.rb
│   │               └── messages/ (2 message type tests)
│   ├── system_cogs/                    # System cogs
│   │   ├── call_test.rb
│   │   ├── map_test.rb
│   │   └── repeat_test.rb
│   ├── execution_manager_test.rb       # Core managers
│   ├── config_manager_test.rb
│   ├── cog_input_manager_test.rb
│   ├── cog_input_context_test.rb
│   ├── workflow_test.rb                # Workflow lifecycle
│   ├── cli_test.rb                     # CLI unit tests
│   ├── cli_e2e_test.rb                 # CLI end-to-end
│   ├── command_runner_test.rb          # Shell boundary
│   ├── event_test.rb                   # Event pipeline
│   ├── event_monitor_test.rb
│   ├── output_router_test.rb
│   ├── task_context_test.rb
│   ├── log_test.rb
│   ├── log_formatter_test.rb
│   └── system_cog_test.rb
├── examples/                           # Functional tests
│   ├── support/
│   │   └── functional_test.rb          # FunctionalTest base class
│   └── functional/
│       └── roast_examples_test.rb      # 29 workflow integration tests
└── fixtures/
    ├── agent_transcripts/              # 5 .stdout.txt files
    │   ├── agent_with_multiple_prompts_0.stdout.txt
    │   ├── agent_with_multiple_prompts_1.stdout.txt
    │   ├── agent_with_multiple_prompts_2.stdout.txt
    │   ├── simple_agent.stdout.txt
    │   └── simple_pi_agent.stdout.txt
    └── vcr_cassettes/                  # 2 HTTP recording files
        ├── simple_chat.yml
        └── temperature.yml
```

**Total**: 60 test files, including 2 support modules, 1 base class, and 57 actual test files.

---

## 4. Test Helper Infrastructure

All shared test infrastructure lives in `test/test_helper.rb` (248 lines). Everything is globally available to all test files.

### 4.1 CaptureLogOutput (Concern)

```ruby
# Included in ALL tests via ActiveSupport::TestCase.include(CaptureLogOutput)
module CaptureLogOutput
  # setup: redirects Roast::Log.logger to a StringIO
  # teardown: on failure, dumps captured output to $stderr; always calls Log.reset!
end
```

**What it does**: Every test gets its own isolated logger. Test output stays clean on success. On failure, the full log is dumped to stderr to aid debugging.

**Access captured output**: `@logger_output.string` within any test.

**Source**: `test/test_helper.rb` lines 34–56

### 4.2 Global Helper Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `slow_test!` | `() -> void` | Skip unless `ROAST_RUN_SLOW_TESTS` is set |
| `with_log_level` | `(Integer) { -> T } -> T` | Temporarily change logger level |
| `with_env` | `(String, String) { -> T } -> T` | Temporarily set an env var |
| `mock_execution_manager` | `(scope:, scope_index:, workflow_context:) -> Mock` | Stub EM with configurable scope |
| `create_workflow_context` | `(targets:, args:, kwargs:, tmpdir:, workflow_dir:) -> WorkflowContext` | Factory with handy defaults |
| `run_cog` | `(Cog, config:, scope_value:, scope_index:) -> Cog` | Full async execution harness |
| `use_command_runner_fixtures` | `(*Hash) -> void` | Sequential CommandRunner stub chain |
| `load_command_runner_fixture_file` | `(String, Symbol) -> String` | Load fixture by name + stream |
| `original_streams_from_logger_output` | `(logger_output:) -> [String, String]` | Reconstruct stdout/stderr from log markers |

### 4.3 `run_cog` — The Integration Test Helper

This is the most important helper. It runs a single cog through the **full async execution path**:

```ruby
def run_cog(cog, config: nil, scope_value: nil, scope_index: 0)
  config ||= cog.class.config_class.new

  Sync do
    barrier = Async::Barrier.new
    input_context = Roast::CogInputContext.new
    Fiber[:path] = [Roast::TaskContext::PathElement.new(execution_manager: mock_execution_manager)]

    cog.run!(barrier, config, input_context, scope_value, scope_index)
    barrier.wait
  end

  cog
end
```

**What it provides**:
1. An `Async::Barrier` (required by `cog.run!`)
2. A bare `CogInputContext` (no bound cog accessors — input blocks see nothing)
3. A fiber-local `[:path]` with a mock PathElement (required by TaskContext)
4. Blocks until the cog completes (`barrier.wait`)
5. Returns the cog for state/output inspection

**When to use it**: Unit-testing a cog's config → input → execute → output lifecycle in isolation. The cog runs as it would in production (inside an async barrier) but without the full ExecutionManager/ConfigManager/CogInputManager orchestration.

**When NOT to use it**: When testing interactions between cogs (output chaining, control flow propagation, scope value passing). Use functional tests for those.

**Source**: `test/test_helper.rb` lines 117–130

### 4.4 `use_command_runner_fixtures` — Sequential Stub Replay

Sets up a Mocha stub for `CommandRunner.execute` that serves fixture files in order. Each invocation of CommandRunner gets the next fixture in sequence.

```ruby
use_command_runner_fixtures(
  {
    fixture: "agent_transcripts/simple_agent",   # Required: fixture name
    exit_code: 0,                                 # Optional (default: 0)
    expected_args: ["claude", "-p", ...],         # Optional: assert args match
    expected_working_directory: Pathname("/tmp"),  # Optional: assert working dir
    expected_timeout: 30,                         # Optional: assert timeout
    expected_stdin_content: "Hello",              # Optional: assert stdin
  },
  { fixture: "agent_transcripts/second_call" },  # Second invocation fixture
)
```

**How it works**:
1. Pre-loads all fixture files (`.stdout.txt`, `.stderr.txt`)
2. Creates mock `Process::Status` objects
3. Stubs `CommandRunner.execute` with a `with` block that:
   - Asserts call count doesn't exceed fixture count
   - Optionally asserts argument expectations per invocation
   - Replays stdout/stderr line-by-line through the handler callbacks
4. Chains `.returns().then.returns()` for sequential return values

**Fixture file resolution**: For fixture name `"agent_transcripts/simple_agent"`:
- Tries `test/fixtures/agent_transcripts/simple_agent.stdout.txt`, then `.stdout.log`
- Tries `test/fixtures/agent_transcripts/simple_agent.stderr.txt`, then `.stderr.log`
- Returns empty string if neither exists

**Source**: `test/test_helper.rb` lines 174–215

### 4.5 `original_streams_from_logger_output` — Stream Reconstruction

Parses the captured log output to separate original stdout and stderr content:

```ruby
stdout, stderr = original_streams_from_logger_output
# or with explicit input:
stdout, stderr = original_streams_from_logger_output(logger_output: some_string)
```

**How it works**: The EventMonitor logs stdout lines with a `❯` marker and stderr lines with `❯❯`. This method:
1. Scans lines for the log prefix pattern (`/^[DIWEFA], \[/`)
2. Identifies `❯❯` lines as stderr, `❯` lines as stdout
3. Continuation lines (without log prefix) belong to the current stream
4. Returns `[stdout_string, stderr_string]`

**When to use**: Functional tests where you need to verify what a workflow actually printed. Direct `capture_io` output should be empty (all output goes through EventMonitor), so this reconstructs what the user would have seen.

**Source**: `test/test_helper.rb` lines 136–160

---

## 5. Test Patterns by Cog Type

### 5.1 Unit Testing a Config Class

```ruby
module Roast
  module Cogs
    class Cmd < Cog
      class ConfigTest < ActiveSupport::TestCase
        def setup
          @config = Config.new
        end

        test "fail_on_error? returns true by default" do
          assert @config.fail_on_error?
        end

        test "no_fail_on_error! sets fail_on_error to false" do
          @config.no_fail_on_error!
          refute @config.fail_on_error?
        end
      end
    end
  end
end
```

**Pattern**: Create a fresh config in `setup`, test each setter/getter pair, verify defaults.

### 5.2 Unit Testing a Cog with `run_cog`

```ruby
test "successful execution sets output" do
  cog = TestCog.new(:my_cog, ->(_input, _scope, _idx) { "hello" })
  run_cog(cog)

  assert cog.succeeded?
  assert_equal "hello", cog.output.value
end
```

**Pattern**: Instantiate cog with a name and input proc, call `run_cog`, assert state and output.

### 5.3 Testing cmd Cogs with Fixtures

```ruby
test "cmd cog captures stdout" do
  use_command_runner_fixtures(
    { fixture: "my_test_fixture", exit_code: 0 }
  )

  # Create and run the cmd cog...
end
```

**Pattern**: Set up fixtures → run cog → verify output fields (`.out`, `.err`, `.status`).

### 5.4 Testing chat Cogs with VCR

```ruby
test "simple chat completes" do
  in_sandbox :simple_chat do
    Roast::Workflow.from_file("examples/simple_chat.rb", EMPTY_PARAMS)
  end
end
```

**Pattern**: Wrap in `in_sandbox` which activates the VCR cassette. The cassette name matches the workflow_id passed to `in_sandbox`.

### 5.5 Testing agent Cogs with Transcript Fixtures

```ruby
test "agent_with_multiple_prompts.rb workflow runs successfully" do
  use_command_runner_fixtures(
    { fixture: "agent_transcripts/agent_with_multiple_prompts_0", expected_args: [...], expected_stdin_content: "What is 2+2?" },
    { fixture: "agent_transcripts/agent_with_multiple_prompts_1", expected_args: [...], expected_stdin_content: "Now multiply that by 3" },
    { fixture: "agent_transcripts/agent_with_multiple_prompts_2", expected_args: [...], expected_stdin_content: "Now subtract 5" },
  )

  stdout, stderr = in_sandbox :simple_agent do
    Roast::Workflow.from_file("examples/agent_with_multiple_prompts.rb", EMPTY_PARAMS)
  end

  assert_empty stdout
  assert_empty stderr

  logged_stdout, _logged_stderr = original_streams_from_logger_output
  assert_equal expected_output, logged_stdout
end
```

**Pattern**: Agent cogs shell out to `claude` CLI (or `pi`). The CommandRunner fixtures replay pre-recorded CLI stdout/stderr. Each prompt in a multi-prompt agent gets its own sequential fixture. Assertions verify:
1. Direct stdout/stderr is empty (all output routed through EventMonitor)
2. Reconstructed logged output matches expected content

---

## 6. Functional Tests (FunctionalTest Base Class)

**Source**: `test/examples/support/functional_test.rb` (60 lines)

### 6.1 The `in_sandbox` Method

```ruby
def in_sandbox(workflow_id, &block)
```

Creates an isolated test environment:

1. **Creates a temporary directory** under `tmp/sandboxes/`
2. **Copies all examples** into the sandbox (`FileUtils.cp_r`)
3. **Sets up VCR**: Uses cassette matching `workflow_id.to_s`
4. **Configures credentials**: Real keys if `RECORD_VCR=true`, fake keys otherwise
5. **Captures IO**: Wraps block in `capture_io`
6. **Scrubs paths**: Replaces tmpdir with `/fake-testing-dir` for stable assertions
7. **CI dump**: If `CI=true`, prints raw stdout/stderr for debugging
8. **Returns**: `[stdout_string, stderr_string]`

### 6.2 Sandbox Preservation

When `PRESERVE_SANDBOX=1` is set, the tmpdir is **not cleaned up**. This lets you inspect the state after a test:

```bash
PRESERVE_SANDBOX=1 ruby -Itest -Ilib test/examples/functional/roast_examples_test.rb -n "/simple_chat/"
ls tmp/sandboxes/simple_chat*/
```

### 6.3 Recording New VCR Cassettes

```bash
RECORD_VCR=true OPENAI_API_KEY=sk-real-key ruby -Itest -Ilib test/examples/functional/roast_examples_test.rb -n "/simple_chat/"
```

VCR will:
- Use the real API key (from environment)
- Record all HTTP interactions to `test/fixtures/vcr_cassettes/simple_chat.yml`
- Filter sensitive data (Authorization headers, cookies, URIs)

### 6.4 Writing a New Functional Test

1. Create an example workflow in `examples/my_workflow.rb`
2. If it uses `agent`: create fixture files in `test/fixtures/agent_transcripts/`
3. If it uses `chat`: record a VCR cassette with `RECORD_VCR=true`
4. Add the test to `test/examples/functional/roast_examples_test.rb`:

```ruby
test "my_workflow.rb runs successfully" do
  # Set up fixtures if needed
  use_command_runner_fixtures(...) # for agent cogs

  stdout, stderr = in_sandbox :my_workflow do
    Roast::Workflow.from_file("examples/my_workflow.rb", EMPTY_PARAMS)
  end

  assert_empty stdout
  assert_empty stderr

  logged_stdout, logged_stderr = original_streams_from_logger_output
  # Assert expected output...
end
```

---

## 7. The TestCog Reference Implementation

**Source**: `test/support/test_cog.rb` (35 lines)

```ruby
module TestCogSupport
  class TestInput < Roast::Cog::Input
    attr_accessor :value

    def validate!
      raise InvalidInputError if value.nil? && !coerce_ran?
    end

    def coerce(input_return_value)
      super  # Sets @coerce_ran = true
      @value = input_return_value
    end
  end

  class TestOutput < Roast::Cog::Output
    attr_reader :value

    def initialize(value)
      super()
      @value = value
    end
  end

  class TestCog < Roast::Cog
    class Config < Roast::Cog::Config; end
    class Input < TestInput; end

    def execute(input)
      TestOutput.new(input.value)
    end
  end
end
```

This is the **minimal complete implementation** of the cog contract. Use it as a template when:
- Writing tests that need a generic cog
- Creating a new custom cog (copy this structure)
- Understanding the Input validate!/coerce two-phase pattern

Key points:
- `validate!` raises `InvalidInputError` when value is nil AND coercion hasn't run
- `coerce` calls `super` (mandatory — sets `coerce_ran?` flag), then sets value
- `execute` receives the validated Input, returns an Output instance
- Config is empty (inherits all base behavior)

---

## 8. Custom Assertions

**Source**: `test/support/improved_assertions.rb` (54 lines)

### `assert_predicate_with_args`

Extends Minitest's `assert_predicate` to accept arguments:

```ruby
# Standard Minitest (no args):
assert_predicate cog, :started?

# Extended (with args):
assert_predicate store, :include?, :my_cog
```

The override dispatches to the original `assert_predicate` when no args are provided, or to the extended version when args are present.

### No `assert_received`

Mocha provides **automatic mock verification**. If you set up an expectation (`expects(:method)`), Mocha verifies it was called during teardown. No manual `assert_received` needed.

---

## 9. Type System (Sorbet)

### Configuration

| Setting | Value | Source |
|---------|-------|--------|
| Sigil level | `typed: true` for ALL 66 lib/ files | Each file's first line |
| `typed: false` files | **0** | — |
| Test files | Excluded from Sorbet | `sorbet/config`: `--ignore=test/` |
| Examples | Excluded from Sorbet | `sorbet/config`: `--ignore=examples/demo` |
| Runtime dependency | `type_toolkit >= 0.0.5` (NOT `sorbet-runtime`) | `roast-ai.gemspec` |
| Experimental features | `--enable-experimental-requires-ancestor`, `--enable-experimental-rbs-comments` | `sorbet/config` |

### Running Sorbet

```bash
bin/srb tc          # Direct invocation
rake sorbet         # Via Rake task
rake                # Part of default task (sorbet + rubocop + minitest_fast)
```

### Inline RBS Annotations

The project uses inline RBS comments (`#:` prefix) for type annotations instead of `sig` blocks:

```ruby
#: (String, Symbol) -> String
def format_message(text, level)
  ...
end

@cogs = Cog::Store.new #: Cog::Store
```

**Stats**: 596 inline RBS annotations across 59 source files.

### RBI Shim Files

Three shim files document the dynamically-defined methods:

| File | Lines | Purpose |
|------|-------|---------|
| `sorbet/rbi/shims/lib/roast/config_context.rbi` | 323 | ConfigContext dynamic methods |
| `sorbet/rbi/shims/lib/roast/execution_context.rbi` | 496 | ExecutionContext dynamic methods |
| `sorbet/rbi/shims/lib/roast/cog_input_context.rbi` | 1,198 | CogInputContext dynamic methods |
| **Total** | **2,017** | — |

These shims serve dual purpose: Sorbet type information AND canonical API documentation. They contain extensive docstrings, usage examples, and cross-references.

### `as untyped` Escape Hatch

7 surgical uses where Sorbet's type system cannot express the actual runtime behavior:

| File | Line | Reason |
|------|------|--------|
| `execution_manager.rb` | 204 | Suppress unknown-length splat warning |
| `cog/config.rb` | 111 | Default value type variance in field macro |
| `command_runner.rb` | 70 | Open3 complex return type |
| `output_router.rb` | 54 | `self` in singleton method context |
| `cogs/ruby.rb` | 112 | Proc reassignment for type narrowing |
| `cogs/ruby.rb` | 140 | Hash value access |
| `cogs/cmd.rb` | 280 | CommandRunner complex return type |

### Generated RBS Files

65 `.rbs` files in `sig/generated/` are auto-generated by `RBS::Inline` from the inline annotations. These stay in sync by re-running the RBS generation tool.

---

## 10. Style Enforcement (RuboCop)

### Configuration

**Source**: `.rubocop.yml`

```yaml
inherit_gem:
  rubocop-shopify: rubocop.yml    # Shopify house style

plugins:
  - rubocop-sorbet
  - type_toolkit:
      require_path: rubocop-type_toolkit

AllCops:
  TargetRubyVersion: 3.4
```

### Key Rules

| Rule | Setting | Effect |
|------|---------|--------|
| `Style/MethodCallWithArgsParentheses` | Enabled (except test/) | Must use parens for method calls with args in lib/ |
| `Sorbet/FalseSigil` | Enabled for `lib/**/*.rb` | Prevents `typed: false` from creeping in |
| `Sorbet/ConstantsFromStrings` | Todolist (4 files) | Legacy workflow files allowed to use `constantize` |
| `Sorbet/SelectByIsA` | Todolist (1 file) | One legacy `select { |x| x.is_a?(Foo) }` |

### Exclusions

| Path | Excluded From |
|------|---------------|
| `bin/*` | AllCops |
| `test/fixtures/**/*` | AllCops |
| `examples/**/*` | AllCops |
| `test/**/*.rb` | MethodCallWithArgsParentheses |
| `test/**/*` | Sorbet/FalseSigil |
| `examples/**/*` | Sorbet/FalseSigil |
| `lib/roast/sorbet_runtime_stub.rb` | Sorbet/FalseSigil (**vestigial** — file no longer exists) |

### Running RuboCop

```bash
rake rubocop        # With autocorrect
rake rubocop_ci     # Without autocorrect (CI mode)
rubocop             # Direct invocation
rubocop --autocorrect-all  # Fix everything possible
```

### Current State

Only 5 offenses in `.rubocop_todo.yml` — all in legacy workflow files that predate the current architecture. The codebase is extremely clean.

---

## 11. Testing Philosophy: Mirrors Architecture

The test pyramid directly reflects the system's structural hierarchy:

| Test Level | What It Tests | Tool | Corresponds To |
|------------|---------------|------|----------------|
| **Unit** | Single Config/Input/Output/cog | Direct instantiation | Individual cog contract |
| **Integration** | Cog within async execution | `run_cog` helper | CM + EM + CIM orchestration |
| **Functional** | Full workflow end-to-end | `FunctionalTest` + `in_sandbox` | CLI → `from_file` → `prepare!` → `start!` |

### Fixture Strategy Reveals Trust Boundaries

Each boundary gets its own isolation approach:

| Boundary | Fixture Strategy | Why |
|----------|-----------------|-----|
| Shell (cmd) | `use_command_runner_fixtures` | Deterministic command replay |
| HTTP/API (chat) | VCR cassettes | Full request/response recording |
| Subprocess (agent) | Agent transcript fixtures | CLI stdout/stderr replay |

### The Sixth Boundary Protection

The FunctionalTest sandbox (copy to tmpdir + path scrubbing) is itself an instance of the framework's deep-copy-at-boundaries pattern — the same philosophy that drives `deep_dup` on config, output access, event paths, and sessions.

---

## 12. Practical Recipes

### Recipe: Adding a Unit Test for a New Config Option

1. Open the corresponding config test file (e.g., `test/roast/cogs/chat/config_test.rb`)
2. Add tests for: default value, setter, negation, validated getter (if applicable)
3. Follow the `setup` → test pairs pattern

### Recipe: Adding a New Functional Test Workflow

1. Create `examples/my_new_workflow.rb`
2. Determine fixture needs:
   - **cmd only**: No fixtures needed (direct execution in sandbox)
   - **agent**: Record CLI output, save as `test/fixtures/agent_transcripts/my_fixture.stdout.txt`
   - **chat**: Run once with `RECORD_VCR=true` to generate cassette
3. Add test in `test/examples/functional/roast_examples_test.rb`
4. Assert: `stdout`/`stderr` empty, then verify `original_streams_from_logger_output`

### Recipe: Debugging a Failing Test

```bash
# 1. Run with verbose logging
ROAST_LOG_LEVEL=0 ruby -Itest -Ilib test/roast/failing_test.rb

# 2. Preserve sandbox for inspection
PRESERVE_SANDBOX=1 ruby -Itest -Ilib test/examples/functional/roast_examples_test.rb -n "/my_test/"

# 3. Check captured log (automatically dumped on failure in test output)

# 4. For parallel/async issues, add explicit barrier.wait or Sync blocks
```

### Recipe: Testing Control Flow

Control flow exceptions (SkipCog, FailCog, Next, Break) propagate differently in sync vs async contexts. When testing:

- **SkipCog**: Always swallowed at Layer 1 — test via `cog.skipped?`
- **FailCog**: Test `abort_on_failure?` behavior by setting config
- **Next/Break**: Must test within a system cog context (Map/Repeat) — use functional tests

### Recipe: Verifying All Checks Pass

```bash
rake  # Runs: sorbet → rubocop → minitest_fast
```

This is the standard pre-commit verification. For full coverage including slow tests:

```bash
rake test  # Runs minitest_all (includes slow tests)
rake check && rake test  # Full verification
```

---

## 13. VCR Configuration

**Source**: `test/test_helper.rb` lines 229–248

```ruby
VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock

  # Filters — replace real values with stable fakes in recordings
  config.filter_sensitive_data("http://mytestingproxy.local/v1/chat/completions") { |i| i.request.uri }
  config.filter_sensitive_data("my-token") { |i| i.request.headers["Authorization"].first }
  config.filter_sensitive_data("<FILTERED>") { |i| i.request.headers["Set-Cookie"] }
  config.filter_sensitive_data("<FILTERED>") { |i| i.response.headers["Set-Cookie"] }
end
```

Key points:
- **Playback mode** (default): Intercepts HTTP, matches against cassette, returns recorded response
- **Record mode** (`RECORD_VCR=true`): Passes through to real API, records everything
- **Sensitive data**: Automatically scrubbed in recordings (API keys, cookies, URIs)
- **Fake credentials**: During playback, env vars are set to dummy values (`"my-token"`, `"http://mytestingproxy.local/v1"`)

---

## 14. Invariants for Test Contributors

1. **Every test file requires `test_helper`** — No exceptions. This ensures CaptureLogOutput is active.
2. **Tests are namespaced under `Roast` module** — Mirrors the lib/ structure.
3. **All tests inherit from `ActiveSupport::TestCase`** — For setup/teardown hooks and CaptureLogOutput.
4. **EventMonitor.reset! in functional test setup/teardown** — Prevents cross-test contamination.
5. **Never assert on direct stdout/stderr in functional tests** — All output goes through EventMonitor. Use `original_streams_from_logger_output` instead.
6. **Fixture count must match invocation count** — `use_command_runner_fixtures` will fail-fast if CommandRunner is called more times than expected.
7. **VCR cassette name must match sandbox workflow_id** — The `in_sandbox` method uses the same string for both.
8. **Mocha auto-verifies** — Don't manually assert expectations. If `expects` is set, Mocha will fail the test if it's not called.
9. **No sorbet-runtime in tests** — Tests are excluded from Sorbet entirely (`--ignore=test/`).
10. **Path scrubbing makes assertions deterministic** — Always compare against `/fake-testing-dir` in functional test assertions.

---

## See Also

- [01 Architecture Overview](01-architecture-overview.md) — System structure that tests mirror
- [03 Cog Reference](03-cog-reference.md) — What each cog's Input/Output/Config looks like
- [10 Writing Custom Cogs](10-writing-custom-cogs.md) — TestCog as template, `run_cog` usage
- [12 Known Issues & Gotchas](12-known-issues-and-gotchas.md) — Edge cases that are hard to test
