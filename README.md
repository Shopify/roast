![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Roast

A convention-oriented framework for creating structured AI workflows, maintained by the Augmented Engineering team at Shopify.

## Why you should use Roast

Roast provides a structured, declarative approach to building AI workflows with:

- **Convention over configuration**: Define powerful workflows using simple YAML configuration files and prompts written in markdown (with ERB support)
- **Built-in tools**: Ready-to-use tools for file operations, search, and AI interactions
- **Ruby integration**: When prompts aren't enough, write custom steps in Ruby using a clean, extensible architecture
- **Shared context**: Each step shares its conversation transcript with its parent workflow by default
- **Step customization**: Steps can be fully configured with their own AI models and parameters.
- **Session replay**: Rerun previous sessions starting at a specified step to speed up development time
- **Parallel execution**: Run multiple steps concurrently to speed up workflow execution
- **Function caching**: Flexibly cache the results of tool function calls to speed up workflows
- **Extensive instrumentation**: Monitor and track workflow execution, AI calls, and tool usage ([see instrumentation documentation](docs/INSTRUMENTATION.md))

## What does it look like?

Here's a simple workflow that analyzes test files:

```yaml
name: analyze_tests
# Default model for all steps
model: gpt-4o-mini
tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::Grep

steps:
  - read_test_file
  - analyze_coverage
  - generate_report

# Step-specific model overrides the global model
analyze_coverage:
  model: gpt-4-turbo
  json: true
```

Each step can have its own prompt file (e.g., `analyze_coverage/prompt.md`) and configuration. Steps can be run in parallel by nesting them in arrays:

```yaml
steps:
  - prepare_data
  -
    - analyze_code_quality
    - check_test_coverage
    - verify_documentation
  - generate_final_report
```

Workflows can include steps that run bash commands (wrap in `$()`), use interpolation with `{{}}` syntax, and even simple inlined prompts as a natural language string.

```yaml
steps:
  - analyze_spec
  - create_minitest
  - run_and_improve
  - $(bundle exec rubocop -A {{file}})
  - Summarize the changes made to {{File.basename(file)}}.
```

## How to use Roast

1. Create a workflow YAML file defining your steps and tools
2. Create prompt files for each step (e.g., `step_name/prompt.md`)
3. Run the workflow:

```bash
# With a target file
roast execute workflow.yml target_file.rb

# Or for a targetless workflow (API calls, data generation, etc.)
roast execute workflow.yml
```

### Understanding Workflows

In Roast, workflows maintain a single conversation with the AI model throughout execution. Each step represents one or more user-assistant interactions within this conversation, with optional tool calls. Steps naturally build upon each other through the shared context.

#### Step Types

Roast supports several types of steps:

1. **Standard step**: References a directory containing at least a `prompt.md` and optional `output.txt` template. This is the most common type of step.
  ```yaml
  steps:
    - analyze_code
  ```

  As an alternative to a directory, you can also implement a custom step as a Ruby class, optionally extending `Roast::Workflow::BaseStep`.

  In the example given above, the script would live at `workflow/analyze_code.rb` and should contain a class named `AnalyzeCode` with an initializer that takes a workflow object as context, and a `call` method that will be invoked to run the step. The result of the `call` method will be stored in the `workflow.output` hash.


2. **Parallel steps**: Groups of steps executed concurrently
   ```yaml
   steps:
     -
       - analyze_code_quality
       - check_test_coverage
   ```

3. **Command execution step**: Executes shell commands directly, just wrap in `$(expr)`
   ```yaml
   steps:
     - $(command line expr)
     - rubocop: $(bundle exec rubocop -A)
   ```
   This will execute the command and store the result in the workflow output hash. Explicit key name is optional (`rubocop` in the second line of the example).

   By default, commands that exit with non-zero status will halt the workflow. You can configure steps to continue on error:
   ```yaml
   steps:
     - lint_check: $(rubocop {{file}})
     - fix_issues
   
   # Step configuration
   lint_check:
     exit_on_error: false  # Continue workflow even if command fails
   ```
   When `exit_on_error: false`, the command output will include the exit status, allowing subsequent steps to process error information.

4. **Conditional steps**: Execute different steps based on conditions using `if/unless`
   ```yaml
   steps:
     - check_environment:
         if: "{{ENV['RAILS_ENV'] == 'production'}}"
         then:
           - run_production_checks
           - notify_team
         else:
           - run_development_setup
     
     - verify_dependencies:
         unless: "$(bundle check)"
         then:
           - bundle_install: "$(bundle install)"
   ```
   
   Conditions can be:
   - Ruby expressions: `if: "{{output['count'] > 5}}"`
   - Bash commands: `if: "$(test -f config.yml && echo true)"` (exit code 0 = true)
   - Step references: `if: "previous_step_name"` (uses the step's output)
   - Direct values: `if: "true"` or `if: "false"`

5. **Iteration steps**: Loop over collections or repeat steps with conditions
   ```yaml
   steps:
     # Loop over a collection
     - process_files:
         each: "{{Dir.glob('**/*.rb')}}"
         as: current_file
         steps:
           - analyze_file
           - Generate a report for {{current_file}}
     
     # Repeat until a condition is met
     - improve_code:
         repeat:
           until: "{{output['test_pass'] == true}}"
           max_iterations: 5
           steps:
             - run_tests
             - fix_issues
   ```
   
   Each loops support:
   - Collections from Ruby expressions: `each: "{{[1, 2, 3]}}"`
   - Command output: `each: "$(ls *.rb)"`
   - Step references: `each: "file_list"`
   
   Repeat loops support:
   - Until conditions: `until: "{{condition}}"`
   - Maximum iterations: `max_iterations: 10`

6. **Raw prompt step**: Simple text prompts for the model without tools
   ```yaml
   steps:
     - Summarize the changes made to the codebase.
   ```
   This creates a simple prompt-response interaction without tool calls or looping. It's detected by the presence of spaces in the step name and is useful for summarization or simple questions at the end of a workflow.

#### Data Flow Between Steps

Roast handles data flow between steps in three primary ways:

1. **Conversation Context (Implicit)**: The LLM naturally remembers the entire conversation history, including all previous prompts and responses. In most cases, this is all you need for a step to reference and build upon previous results. This is the preferred approach for most prompt-oriented workflows.

2. **Output Hash (Explicit)**: Each step's result is automatically stored in the `workflow.output` hash using the step name as the key. This programmatic access is mainly useful when:
   - You need to perform non-LLM transformations on data
   - You're writing custom output logic
   - You need to access specific values for presentation or logging

3. **Interpolation (Dynamic)**: You can use `{{expression}}` syntax to inject values from the workflow context directly into step names, commands, or prompt text. For example:
   ```yaml
   steps:
     - analyze_file
     - $(rubocop -A {{file}})
     - Generate a summary for {{file}}
     - result_for_{{file}}: store_results
   ```

   Interpolation supports:
   - Simple variable access: `{{file}}`, `{{resource.target}}`
   - Access to step outputs: `{{output['previous_step']}}`
   - Any valid Ruby expression evaluated in the workflow context: `{{File.basename(file)}}`

For typical AI workflows, the continuous conversation history provides seamless data flow without requiring explicit access to the output hash. Steps can simply refer to previous information in their prompts, and the AI model will use its memory of the conversation to provide context-aware responses. For more dynamic requirements, the interpolation syntax provides a convenient way to inject context-specific values into steps.

### Command Line Options

#### Basic Options
- `-o, --output FILE`: Save results to a file instead of outputting to STDOUT
- `-c, --concise`: Use concise output templates (exposed as a boolean flag on `workflow`)
- `-v, --verbose`: Show output from all steps as they execute
- `-r, --replay STEP_NAME`: Resume a workflow from a specific step, optionally with a specific session timestamp

#### Session Replay

The session replay feature allows you to resume workflows from specific steps, saving time during development and debugging:

```bash
# Resume from a specific step
roast execute workflow.yml -r step_name

# Resume from a specific step in a specific session
roast execute workflow.yml -r 20250507_123456_789:step_name
```

Sessions are automatically saved during workflow execution. Each step's state, including the conversation transcript and output, is persisted to a session directory. The session directories are organized by workflow name and file, with timestamps for each run.

This feature is particularly useful when:
- Debugging specific steps in a long workflow
- Iterating on prompts without rerunning the entire workflow
- Resuming after failures in long-running workflows

Sessions are stored in the `.roast/sessions/` directory in your project. Note that there is no automatic cleanup of session data, so you might want to periodically delete old sessions yourself.

#### Target Option (`-t, --target`)

The target option is highly flexible and accepts several formats:

**Single file path:**
```bash
roast execute workflow.yml -t path/to/file.rb

# is equivalent to
roast execute workflow.yml path/to/file.rb
```

**Directory path:**
```bash
roast execute workflow.yml -t path/to/directory

# Roast will run on the directory as a resource
```

**Glob patterns:**
```bash
roast execute workflow.yml -t "**/*_test.rb"

# Roast will run the workflow on each matching file
```

**URL as target:**
```bash
roast execute workflow.yml -t "https://api.example.com/data"

# Roast will run the workflow using the URL as a resource
```

**API configuration (Fetch API-style):**
```bash
roast execute workflow.yml -t '{
  "url": "https://api.example.com/resource",
  "options": {
    "method": "POST",
    "headers": {
      "Content-Type": "application/json",
      "Authorization": "Bearer ${API_TOKEN}"
    },
    "body": {
      "query": "search term",
      "limit": 10
    }
  }
}'

# Roast will recognize this as an API configuration with Fetch API-style format
```

**Shell command execution with $(...):**
```bash
roast execute workflow.yml -t "$(find . -name '*.rb' -mtime -1)"

# Roast will run the workflow on each file returned (expects one per line)
```

**Git integration examples:**
```bash
# Process changed test files
roast execute workflow.yml -t "$(git diff --name-only HEAD | grep _test.rb)"

# Process staged files
roast execute workflow.yml -t "$(git diff --cached --name-only)"
```

#### Targetless Workflows

Roast also supports workflows that don't operate on a specific pre-defined set of target files:

**API-driven workflows:**
```yaml
name: API Integration Workflow
tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile

# Dynamic API token using shell command
api_token: $(cat ~/.my_token)

# Option 1: Use a targetless workflow with API logic in steps
steps:
  - fetch_api_data  # Step will make API calls
  - transform_data
  - generate_report

# Option 2: Specify an API target directly in the workflow
target: '{
  "url": "https://api.example.com/resource",
  "options": {
    "method": "GET",
    "headers": {
      "Authorization": "Bearer ${API_TOKEN}"
    }
  }
}'

steps:
  - process_api_response
  - generate_report
```

**Data generation workflows:**
```yaml
name: Generate Documentation
tools:
  - Roast::Tools::WriteFile
steps:
  - generate_outline
  - write_documentation
  - create_examples
```

These targetless workflows are ideal for:
- API integrations
- Content generation
- Report creation
- Interactive tools
- Scheduled automation tasks

#### Global Model Configuration

You can set a default model for all steps in your workflow by specifying the `model` parameter at the top level:

```yaml
name: My Workflow
model: gpt-4o-mini  # Will be used for all steps unless overridden
```

Individual steps can override this setting with their own model parameter:

```yaml
analyze_data:
  model: anthropic/claude-3-haiku  # Takes precedence over the global model
```

#### API Provider Configuration

Roast supports both OpenAI and OpenRouter as API providers. By default, Roast uses OpenAI, but you can specify OpenRouter:

```yaml
name: My Workflow
api_provider: openrouter
api_token: $(echo $OPENROUTER_API_KEY)
model: anthropic/claude-3-opus-20240229
```

Benefits of using OpenRouter:
- Access to multiple model providers through a single API
- Support for models from Anthropic, Meta, Mistral, and more
- Consistent API interface across different model providers

When using OpenRouter, specify fully qualified model names including the provider prefix (e.g., `anthropic/claude-3-opus-20240229`).

#### Dynamic API Tokens

Roast allows you to dynamically fetch API tokens using shell commands directly in your workflow configuration:

```yaml
# This will execute the shell command and use the result as the API token
api_token: $(print-token --key)

# For OpenAI (default)
api_token: $(echo $OPENAI_API_KEY)

# For OpenRouter (requires api_provider setting)
api_provider: openrouter
api_token: $(echo $OPENROUTER_API_KEY)
```


This makes it easy to use environment-specific tokens without hardcoding credentials, especially useful in development environments or CI/CD pipelines. Alternatively, Roast will fall back to `OPENROUTER_API_KEY` or `OPENAI_API_KEY` environment variables based on the specified provider.

#### Automatic Context Management

Roast includes automatic context management to handle LLM token limits in long-running workflows. When enabled, it monitors the conversation length and automatically compacts the transcript when approaching token limits, ensuring workflows can continue without interruption.

**Basic Configuration:**
```yaml
name: Long Running Workflow
model: gpt-4o-mini
context_management:
  enabled: true
  threshold: 0.8  # Trigger compaction at 80% of model's max tokens
  strategy: truncation  # Options: "truncation" or "llm_summarization"
```

**Advanced Configuration:**
```yaml
context_management:
  enabled: true
  threshold: 0.75
  strategy: llm_summarization
  max_tokens: 50000  # Override auto-detected model limit
  character_to_token_ratio: 0.25  # Override model-specific ratio
  post_compaction_threshold_buffer: 0.9  # Target 90% of threshold after compaction
  summarization_model: gemini-2.0-flash  # Override auto-selected model for summaries
```

**Configuration Options:**

- **`enabled`** (boolean, default: `false`): Enable/disable automatic context management
- **`threshold`** (number, 0.0-1.0, default: 0.8): Token usage percentage that triggers compaction
- **`strategy`** (string, default: `"truncation"`): Compaction method. Options:
  - `"truncation"`: Removes oldest messages while preserving recent context (fast, reliable)
  - `"llm_summarization"`: Uses LLM to summarize old content into concise summaries (preserves more context, slower)
- **`max_tokens`** (integer, optional): Override the auto-detected model token limit
- **`character_to_token_ratio`** (number, 0.0-1.0, optional): Override model-specific character-to-token estimation
- **`post_compaction_threshold_buffer`** (number, 0.0-1.0, default: 0.9): Target percentage of threshold to reach after compaction. This setting determines how much buffer space remains after context compaction.

  **Example**: With a model limit of 128,000 tokens, threshold of 0.8 (102,400 tokens), and `post_compaction_threshold_buffer` of 0.9:
  
  - Compaction triggers when conversation reaches 102,400 tokens (80% of 128,000)
  - After compaction, transcript is reduced to ~92,160 tokens (90% of 102,400)
  - This leaves 10,240 tokens of buffer space for the next LLM response
  - Lower values (e.g., 0.7) provide more buffer but remove more context
  - Higher values (e.g., 0.95) preserve more context but may trigger frequent re-compaction
- **`summarization_model`** (string, optional): Override model for LLM summarization. Auto-selects optimal models if not specified:
  - GPT-4/o1 → `gpt-4o-mini` (fast, cost-effective)
  - Claude Opus/Sonnet → `claude-3-5-haiku-20241022` (fastest Claude model)
  - Gemini Pro models → `gemini-2.0-flash` (stable fast model)
  - Gemini experimental/preview → `gemini-2.0-flash` (stable alternative)
  - Unknown models → `gemini-2.0-flash` (default stable option)
  
  **Note**: For production reliability, experimental (`-exp`) and preview (`-preview`) models are automatically mapped to stable equivalents for summarization tasks.

**How It Works:**

1. **Automatic Monitoring**: Before each LLM call, Roast estimates the current token usage
2. **Smart Compaction**: When the threshold is reached, it compacts the conversation transcript while preserving the most recent context
3. **Tool Integration**: Built-in tools (`read_file`, `grep`) automatically receive `max_tokens` limits to prevent oversized responses
4. **Model Awareness**: Uses model-specific token counting (tiktoken for OpenAI) and character-to-token ratios for other providers

This feature is particularly valuable for:
- Long-running analysis workflows
- Iterative code review processes  
- Multi-file processing workflows
- Interactive debugging sessions

When disabled (default), workflows will fail with token limit errors if they exceed the model's context window.

### Template Output with ERB

Each step can have an `output.txt` file that uses ERB templating to format the final output. This allows you to customize how the AI's response is processed and displayed.

Example `step_name/output.txt`:
```erb
<% if workflow.verbose %>
Detailed Analysis:
<%= response %>
<% else %>
Summary: <%= response.lines.first %>
<% end %>

Files analyzed: <%= workflow.file %>
Status: <%= workflow.output['status'] || 'completed' %>
```

This is an example of where the `workflow.output` hash is useful - formatting output for display based on data from previous steps.

Available in templates:
- `response`: The AI's response for this step
- `workflow`: Access to the workflow object
- `workflow.output`: The shared hash containing results from all steps when you need programmatic access
- `workflow.file`: Current file being processed (or `nil` for targetless workflows)
- All workflow configuration options

For most workflows, you'll mainly use `response` to access the current step's results. The `workflow.output` hash becomes valuable when you need to reference specific data points from previous steps in your templates or for conditional display logic.

## Advanced Features

### Instrumentation

Roast provides extensive instrumentation capabilities using ActiveSupport::Notifications. You can monitor workflow execution, track AI model usage, measure performance, and integrate with external monitoring systems. [Read the full instrumentation documentation](docs/INSTRUMENTATION.md).

### Built-in Tools

Roast provides several built-in tools that you can use in your workflows:

#### ReadFile

Reads the contents of a file from the filesystem.

```ruby
# Basic usage
read_file(path: "path/to/file.txt")

# Reading a specific portion of a file
read_file(path: "path/to/large_file.txt", offset: 100, limit: 50)
```

- The `path` can be absolute or relative to the current working directory
- Use `offset` and `limit` for large files to read specific sections (line numbers)
- Returns the file content as a string

#### WriteFile

Writes content to a file, creating the file if it doesn't exist or overwriting it if it does.

```ruby
# Basic usage
write_file(path: "output.txt", content: "This is the file content")

# With path restriction for security
write_file(
  path: "output.txt",
  content: "Restricted content",
  restrict: "/safe/directory" # Only allows writing to files under this path
)
```

- Creates missing directories automatically
- Can restrict file operations to specific directories for security
- Returns a success message with the number of lines written

#### UpdateFiles

Applies a unified diff/patch to one or more files. Changes are applied atomically when possible.

```ruby
update_files(
  diff: <<~DIFF,
    --- a/file1.txt
    +++ b/file1.txt
    @@ -1,3 +1,4 @@
     line1
    +new line
     line2
     line3

    --- a/file2.txt
    +++ b/file2.txt
    @@ -5,7 +5,7 @@
     line5
     line6
    -old line7
    +updated line7
     line8
  DIFF
  base_path: "/path/to/project", # Optional, defaults to current working directory
  restrict_path: "/path/to/allowed", # Optional, restricts where files can be modified
  create_files: true, # Optional, defaults to true
)
```

- Accepts standard unified diff format from tools like `git diff`
- Supports multiple file changes in a single operation
- Handles file creation, deletion, and modification
- Performs atomic operations with rollback on failure
- Includes fuzzy matching to handle minor context differences
- This tool is especially useful for making targeted changes to multiple files at once

#### Grep

Searches file contents for a specific pattern using regular expressions.

```ruby
# Basic usage
grep(pattern: "function\\s+myFunction")

# With file filtering
grep(pattern: "class\\s+User", include: "*.rb")

# With directory scope
grep(pattern: "TODO:", path: "src/components")
```

- Uses regular expressions for powerful pattern matching
- Can filter by file types using the `include` parameter
- Can scope searches to specific directories with the `path` parameter
- Returns a list of files containing matches

#### SearchFile

Provides advanced file search capabilities beyond basic pattern matching.

```ruby
search_file(query: "class User", file_path: "app/models")
```

- Combines pattern matching with contextual search
- Useful for finding specific code structures or patterns
- Returns matched lines with context

#### Cmd

Executes shell commands and returns their output.

```ruby
# Execute a simple command
cmd(command: "ls -la")

# With working directory specified
cmd(command: "npm list", cwd: "/path/to/project")

# With environment variables
cmd(command: "deploy", env: { "NODE_ENV" => "production" })
```

- Provides access to shell commands for more complex operations
- Can specify working directory and environment variables
- Captures and returns command output
- Useful for integrating with existing tools and scripts

#### CodingAgent

Creates a specialized agent for complex coding tasks or long-running operations.

```ruby
coding_agent(
  task: "Refactor the authentication module to use JWT tokens",
  language: "ruby",
  files: ["app/models/user.rb", "app/controllers/auth_controller.rb"]
)
```

- Delegates complex tasks to a specialized coding agent
- Useful for tasks that require deep code understanding or multi-step changes
- Can work across multiple files and languages

### Custom Tools

You can create your own tools using the [Raix function dispatch pattern](https://github.com/OlympiaAI/raix-rails?tab=readme-ov-file#use-of-toolsfunctions). Custom tools should be placed in `.roast/initializers/` (subdirectories are supported):

```ruby
# .roast/initializers/tools/git_analyzer.rb
module MyProject
  module Tools
    module GitAnalyzer
      extend self

      def self.included(base)
        base.class_eval do
          function(
            :analyze_commit,
            "Analyze a git commit for code quality and changes",
            commit_sha: { type: "string", description: "The SHA of the commit to analyze" },
            include_diff: { type: "boolean", description: "Include the full diff in the analysis", default: false }
          ) do |params|
            GitAnalyzer.call(params[:commit_sha], params[:include_diff])
          end
        end
      end

      def call(commit_sha, include_diff = false)
        Roast::Helpers::Logger.info("🔍 Analyzing commit: #{commit_sha}\n")

        # Your implementation here
        commit_info = `git show #{commit_sha} --stat`
        commit_info += "\n\n" + `git show #{commit_sha}` if include_diff

        commit_info
      rescue StandardError => e
        "Error analyzing commit: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
        end
      end
    end
  end
end
```

Then include your tool in the workflow:

```yaml
tools:
  - MyProject::Tools::GitAnalyzer
```

The tool will be available to the AI model during workflow execution, and it can call `analyze_commit` with the appropriate parameters.

### Project-specific Configuration

You can extend Roast with project-specific configuration by creating initializers in `.roast/initializers/`. These are automatically loaded when workflows run, allowing you to:

- Add custom instrumentation
- Configure monitoring and metrics
- Set up project-specific tools
- Customize workflow behavior

Example structure:
```
your-project/
  ├── .roast/
  │   └── initializers/
  │       ├── metrics.rb
  │       ├── logging.rb
  │       └── custom_tools.rb
  └── ...
```

## Installation

```bash
$ gem install roast-ai
```

Or add to your Gemfile:

```ruby
gem 'roast-ai'
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake` to run the tests and linter. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
