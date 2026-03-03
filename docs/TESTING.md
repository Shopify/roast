# Testing Your Roast Workflows

Roast provides a built-in test framework for writing fast, reliable tests against your workflows. Tests run in isolated sandboxes and can optionally record/replay HTTP requests using VCR.

## Quick Start

Add `roast-ai` to your Gemfile (if not already there), along with your preferred test dependencies:

```ruby
# Gemfile
gem "roast-ai"
gem "minitest"
gem "activesupport"

# Optional: for recording/replaying HTTP requests
gem "vcr"
gem "webmock"

# Optional: for use_command_runner_fixture (agent testing)
gem "mocha"
```

Create a test file:

```ruby
# test/workflows/my_workflow_test.rb
require "roast"
require "roast/testing/test_case"
require "minitest/autorun"

class MyWorkflowTest < Roast::Testing::TestCase
  # Point to the directory containing your workflow files
  self.workflow_dir = File.expand_path("../../workflows", __dir__)

  test "my workflow runs successfully" do
    stdout, stderr = in_sandbox(:my_workflow) do
      Roast::Workflow.from_file("workflows/my_workflow.rb", EMPTY_PARAMS)
    end

    assert_empty stderr
    assert_includes stdout, "expected output"
  end
end
```

Run it:

```bash
bundle exec ruby -Itest test/workflows/my_workflow_test.rb
```

## How It Works

### Sandbox Isolation

`in_sandbox` creates a temporary directory, copies your workflow files into it, and runs your block inside that directory. This ensures tests don't interfere with each other or your real files.

After execution, any references to the temp directory path in stdout/stderr are replaced with `/fake-testing-dir` for stable assertions.

```ruby
stdout, stderr = in_sandbox(:my_test) do
  # Your workflow runs here in an isolated temp directory
  Roast::Workflow.from_file("workflows/example.rb", EMPTY_PARAMS)
end

# stdout and stderr are captured strings with sanitized paths
assert_includes stdout, "Hello from /fake-testing-dir"
```

### EMPTY_PARAMS

`Roast::Testing::TestCase` provides the `EMPTY_PARAMS` constant — an empty `WorkflowParams` instance. Use it when your workflow doesn't need targets or arguments:

```ruby
Roast::Workflow.from_file("my_workflow.rb", EMPTY_PARAMS)
```

To test with parameters:

```ruby
params = Roast::WorkflowParams.new(
  ["target_file.rb"],  # targets
  [],                   # positional args
  { verbose: "true" }   # keyword args
)
Roast::Workflow.from_file("my_workflow.rb", params)
```

## Recording HTTP Requests with VCR

If your workflows make API calls (chat, agents, etc.), you can use VCR to record and replay them. This makes tests fast and deterministic without needing real API credentials.

### Setup

Add `vcr` and `webmock` to your Gemfile, then require them before `roast/testing/test_case`:

```ruby
require "vcr"
require "webmock"
require "roast/testing/test_case"
```

`TestCase` automatically detects VCR and configures it with sensible defaults:
- Cassettes stored in `test/fixtures/vcr_cassettes/`
- API keys and cookies filtered from recordings
- WebMock integration enabled

### Recording

First run with real credentials to record:

```bash
RECORD_VCR=true OPENAI_API_KEY=sk-... bundle exec ruby -Itest test/workflows/my_workflow_test.rb
```

This creates a cassette file in `test/fixtures/vcr_cassettes/my_workflow.yml`.

### Replaying

Subsequent runs replay from the cassette — no API calls, no credentials needed:

```bash
bundle exec ruby -Itest test/workflows/my_workflow_test.rb
```

### Without VCR

If you don't add VCR to your Gemfile, tests run live against real APIs. This is fine for workflows that don't make HTTP requests or when you want integration testing.

## Testing Agent Workflows

For workflows that invoke external commands (like the Claude CLI), use `use_command_runner_fixture` to stub `CommandRunner.execute` with fixture files:

```ruby
test "agent workflow processes correctly" do
  # Create fixture files:
  #   test/fixtures/my_agent.stdout.txt
  #   test/fixtures/my_agent.stderr.txt
  use_command_runner_fixture("my_agent")

  stdout, stderr = in_sandbox(:my_agent_test) do
    Roast::Workflow.from_file("workflows/agent_workflow.rb", EMPTY_PARAMS)
  end

  assert_empty stderr
end
```

The fixture method accepts options for validation:

```ruby
use_command_runner_fixture(
  "my_agent",
  exit_code: 0,
  expected_args: ["claude", "--chat"],
  expected_working_directory: "/expected/path",
  expected_timeout: 30
)
```

## Configuration

All settings are configurable via class attributes:

```ruby
class MyWorkflowTest < Roast::Testing::TestCase
  # Directory containing your workflow files (copied into sandbox)
  # Defaults to ./examples/ if not set
  self.workflow_dir = "/path/to/workflows"

  # Optional: where VCR cassettes are stored (default: test/fixtures/vcr_cassettes)
  self.cassette_library_dir = "test/cassettes"

  # Optional: root directory for sandbox temp dirs (default: tmp/sandboxes)
  self.sandbox_root = "/tmp/my_sandboxes"

  # Optional: where command runner fixtures live (default: test/fixtures)
  self.fixture_dir = "test/my_fixtures"

  # Optional: environment variable names for API credentials
  self.api_key_env_var = "ANTHROPIC_API_KEY"
  self.api_base_env_var = "ANTHROPIC_API_BASE"

  # Optional: fake values used during VCR playback
  self.fake_api_key = "test-key"
  self.fake_api_base = "http://localhost:4000"
end
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RECORD_VCR=true` | Record new VCR cassettes (uses real API credentials) |
| `PRESERVE_SANDBOX=true` | Keep temp sandbox directories after test runs (for debugging) |
| `CI=true` | Print captured stdout/stderr to console (useful in CI pipelines) |

## Common Patterns

### Testing workflow output

```ruby
test "workflow produces expected output" do
  stdout, stderr = in_sandbox(:output_test) do
    Roast::Workflow.from_file("workflows/greeter.rb", EMPTY_PARAMS)
  end

  assert_empty stderr
  assert_match(/Hello, world/i, stdout)
end
```

### Testing error handling

```ruby
test "workflow handles missing file gracefully" do
  assert_raises(Roast::Error) do
    in_sandbox(:error_test) do
      Roast::Workflow.from_file("workflows/nonexistent.rb", EMPTY_PARAMS)
    end
  end
end
```

### Multiple test classes with different configs

```ruby
class ChatWorkflowTest < Roast::Testing::TestCase
  self.workflow_dir = File.expand_path("../workflows/chat", __dir__)
  self.cassette_library_dir = "test/fixtures/chat_cassettes"

  # chat workflow tests...
end

class AgentWorkflowTest < Roast::Testing::TestCase
  self.workflow_dir = File.expand_path("../workflows/agents", __dir__)
  self.fixture_dir = "test/fixtures/agent_transcripts"

  # agent workflow tests...
end
```

## Troubleshooting

### "Workflow directory not found"
Set `self.workflow_dir` to the directory containing your workflow files. It must exist at test time.

### VCR cassette errors
If you see `VCR::Errors::UnhandledHTTPRequestError`, your workflow is making HTTP requests not in the cassette. Re-record with `RECORD_VCR=true`.

### Tests are slow
Make sure VCR cassettes exist for workflows that make API calls. Without cassettes, tests hit real APIs.

### Temp directories filling up
Sandbox directories are cleaned up automatically. Set `PRESERVE_SANDBOX=true` only when debugging, and clean up `tmp/sandboxes/` manually afterward.
