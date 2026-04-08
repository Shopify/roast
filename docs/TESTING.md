# Testing Your Roast Workflows

`Roast::Testing::TestCase` provides sandbox isolation and optional VCR recording/playback for testing workflows.

## Quick Start

```ruby
# test/workflows/my_workflow_test.rb
require "roast"
require "roast/testing/test_case"
require "minitest/autorun"

class MyWorkflowTest < Roast::Testing::TestCase
  self.workflow_dir = File.expand_path("../../workflows", __dir__)

  test "my workflow runs successfully" do
    stdout, stderr = in_sandbox(:my_workflow) do
      Roast::Workflow.from_file("workflows/my_workflow.rb", EMPTY_PARAMS)
    end
    assert_empty stderr
  end
end
```

## Sandbox Isolation

`in_sandbox` creates a temp directory, copies `workflow_dir` **into** it (preserving the basename), and captures stdout/stderr. Temp paths in output are replaced with `/fake-testing-dir`.

Paths passed to `Workflow.from_file` should include the directory name (e.g. `"workflows/my_workflow.rb"` when `workflow_dir` points to a `workflows/` directory).

`EMPTY_PARAMS` is a frozen `WorkflowParams` with no targets or arguments.

## VCR Recording (Optional)

Add `vcr` and `webmock` to your Gemfile and require them before `roast/testing/test_case`. TestCase auto-configures VCR with filtered API keys, cookies, and cassettes in `test/fixtures/vcr_cassettes/`.

```bash
# Record (only "true" enables recording)
RECORD_VCR=true OPENAI_API_KEY=sk-... bundle exec ruby -Itest test/workflows/my_test.rb

# Replay (default — no credentials needed)
bundle exec ruby -Itest test/workflows/my_test.rb
```

Without VCR in your Gemfile, tests run live against real APIs.

> **Note:** VCR has a single global `cassette_library_dir`. Configure VCR in your own `test_helper.rb` before loading `Roast::Testing::TestCase` if you need per-class cassette directories.

## Agent Testing (Optional)

For workflows invoking external commands (e.g. Claude CLI), use `use_command_runner_fixtures` to stub `CommandRunner.execute` with fixture files. Requires the `mocha` gem.

```ruby
# Reads test/fixtures/my_agent.stdout.txt and .stderr.txt
use_command_runner_fixtures(
  { fixture: "my_agent", expected_args: ["claude", "--chat"] }
)
```

For multi-invocation workflows, pass multiple specs:

```ruby
use_command_runner_fixtures(
  { fixture: "agent_turn_1", expected_stdin_content: "Hello" },
  { fixture: "agent_turn_2", expected_stdin_content: "Follow up" },
)
```

Each spec accepts: `:fixture`, `:exit_code` (default 0), `:expected_args`, `:expected_working_directory`, `:expected_timeout`, `:expected_stdin_content`.

## Configuration

```ruby
class MyWorkflowTest < Roast::Testing::TestCase
  self.workflow_dir = "/path/to/workflows"       # required; copied into sandbox
  self.sandbox_root = "/tmp/my_sandboxes"         # default: tmp/sandboxes
  self.fixture_dir = "test/my_fixtures"           # default: test/fixtures
  self.api_key_env_var = "ANTHROPIC_API_KEY"      # default: OPENAI_API_KEY
  self.api_base_env_var = "ANTHROPIC_API_BASE"    # default: OPENAI_API_BASE
  self.fake_api_key = "test-key"                  # default: my-token
  self.fake_api_base = "http://localhost:4000"    # default: http://mytestingproxy.local/v1
end
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RECORD_VCR=true` | Record VCR cassettes with real API credentials |
| `PRESERVE_SANDBOX=true` | Keep sandbox temp dirs after tests (for debugging) |
| `CI=true` | Print captured stdout/stderr to console |
