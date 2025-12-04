![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Roast

> **📢 Code Freeze Notice**: This project is currently under a limited code freeze while we work on an alternative frontend (a DSL). We are still accepting **bug fixes**, but **new features** will not be merged until the DSL is released. Thank you for your understanding!

A convention-oriented framework for creating structured AI workflows, maintained by the Augmented Engineering team at Shopify.

## Installation

```bash
$ gem install roast-ai
```

Or add to your Gemfile:

```ruby
gem 'roast-ai'
```

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

# Step-specific config that specifies a custom path, not in the current directory
generate_report:
  path: ../reporting/generate_report
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

## Try it

If you don’t have one already, get an OpenAI key from [here](https://platform.openai.com/settings/organization/api-keys). You will need an account with a credit card and credits applied to the associated project. Make sure that a basic completion works:

```bash
export OPENAI_API_KEY=sk-proj-....

curl -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{"model":"gpt-4.1-mini","messages":[{"role":"user","content":"What is 1+1?"}]}' \
    https://api.openai.com/v1/chat/completions
```

The [test grading workflow](examples/grading/workflow.md) in this repository is a senior software engineer and testing expert that evaluates the quality of a test based on guidelines.

Try the workflow.

```bash
./exe/roast execute examples/grading/workflow.yml test/roast/resources_test.rb

🔥🔥🔥 Everyone loves a good roast 🔥🔥🔥
...
```

This will output a test grade.

```
========== TEST GRADE REPORT ==========
Test file: test/roast/resources_test.rb

FINAL GRADE:
  Score: 80/100
  Letter Grade: B
```
Note that you may also need `shadowenv` and `rg`, on MacOS run `brew install shadowenv` and `brew install rg`.

## How to use Roast

1. Create a workflow YAML file defining your steps and tools
2. Create prompt files for each step (e.g., `step_name/prompt.md`)
3. Run the workflow:

```bash
# With a target file
roast execute workflow.yml target_file.rb

# Or for a targetless workflow (API calls, data generation, etc.)
roast execute workflow.yml

# Roast will automatically search in `project_root/roast/workflow_name` if the path is incomplete.
roast execute my_cool_workflow # Equivalent to `roast execute roast/my_cool_workflow/workflow.yml
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

6. **Case/when/else steps**: Select different execution paths based on a value (similar to Ruby's case statement)
   ```yaml
   steps:
     - detect_language

     - case: "{{ workflow.output.detect_language }}"
       when:
         ruby:
           - lint_with_rubocop
           - test_with_rspec
         javascript:
           - lint_with_eslint
           - test_with_jest
         python:
           - lint_with_pylint
           - test_with_pytest
       else:
         - analyze_generic
         - generate_basic_report
   ```

   Case expressions can be:
   - Workflow outputs: `case: "{{ workflow.output.variable }}"`
   - Ruby expressions: `case: "{{ count > 10 ? 'high' : 'low' }}"`
   - Bash commands: `case: "$(echo $ENVIRONMENT)"`
   - Direct values: `case: "production"`

   The value is compared against each key in the `when` clause, and matching steps are executed.
   If no match is found, the `else` steps are executed (if provided).

7. **Raw prompt step**: Simple text prompts for the model without tools
   ```yaml
   steps:
     - Summarize the changes made to the codebase.
   ```
   This creates a simple prompt-response interaction without tool calls or looping. It's detected by the presence of spaces in the step name and is useful for summarization or simple questions at the end of a workflow.

8. **Agent step**: Direct pass-through to coding agents (e.g., Claude Code)
   ```yaml
   steps:
     - ^fix_linting_errors                                    # File-based agent prompt
     - ^Review the code and identify any performance issues   # Inline agent prompt
     - regular_analysis                                       # Normal step through LLM
   ```
   Agent steps are prefixed with `^` and send the prompt content directly to the CodingAgent tool without LLM translation. This is useful when you want to give precise instructions to a coding agent without the intermediate interpretation layer. Agent steps support both file-based prompts (`fix_linting_errors/prompt.md`) and inline prompts (text with spaces).

   **Session continuity for agent steps:**
   
   Agent steps support two options for maintaining Claude context across steps:
   
   1. **`continue: true`** - Continues from the immediately previous Claude Code session (note, if multiple Claude Code sessions are being run in parallel in the same working directory, this might not be the previous Claude Code session from this workflow) 
   2. **`resume: step_name`** - Resumes from a specific earlier step's Claude Code session
   
   **Continue option:**
   
   The `continue` option allows sequential agent steps to maintain a continuous conversation:
   
   ```yaml
   steps:
     - ^analyze_codebase
     - ^implement_feature
     - ^add_tests
   
   # Configuration
   analyze_codebase:
     continue: false  # Start fresh (default)
   
   implement_feature:
     continue: true   # Continue from immediately previous analyze_codebase step
   
   add_tests:
     continue: true   # Continue from immediately previous implement_feature step
   ```
   
   **Resume functionality for agent steps:**
   
   Agent steps can resume from specific previous Claude Code sessions:
   
   ```yaml
   steps:
     - ^analyze_codebase
     - ^implement_feature
     - ^polish_implementation
   
   # Configuration
   analyze_codebase:
     continue: false  # Start fresh
   
   implement_feature:
     continue: true   # Continue from previous conversation
   
   polish_implementation:
     resume: analyze_codebase  # Resume from a specific step's session not the immediately previous one
   ```
   
   Note: Session IDs are only available when the CodingAgent is configured to output JSON format (includes `--output-format stream-json` in the command). If you are using a custom CodingAgent command that does not produce JSON output, resume functionality will not be available.

   If `resume` is specified but the step name given does not have CodingAgent session to resume from, the CodingAgent will start Claude Code with a fresh session. 

9. **Shell script step**: Execute shell scripts directly as workflow steps
   ```yaml
   steps:
     - setup_environment     # Executes setup_environment.sh
     - run_tests             # Executes run_tests.sh  
     - cleanup
   ```
   
   Shell script steps allow you to execute `.sh` files directly as workflow steps alongside Ruby steps and AI prompts. Scripts are automatically discovered in the same locations as other step types.
   
   **Configuration options:**
   ```yaml
   # Step configuration  
   my_script:
     json: true              # Parse stdout as JSON
     exit_on_error: false    # Don't fail workflow on non-zero exit
     env:                    # Custom environment variables
       CUSTOM_VAR: "value"
   ```
   
   **Environment integration:** Shell scripts automatically receive workflow context:
   - `ROAST_WORKFLOW_RESOURCE`: Current workflow resource
   - `ROAST_STEP_NAME`: Current step name
   - `ROAST_WORKFLOW_OUTPUT`: Previous step outputs as JSON
   
   **Example script (`setup_environment.sh`):**
   ```bash
   #!/bin/bash
   echo "Setting up environment for: $ROAST_WORKFLOW_RESOURCE"
   
   # Create a config file that subsequent steps can use
   mkdir -p tmp
   echo "DATABASE_URL=sqlite://test.db" > tmp/config.env
   
   # Output data for the workflow (available via ROAST_WORKFLOW_OUTPUT in later steps)
   echo '{"status": "configured", "database": "sqlite://test.db", "config_file": "tmp/config.env"}'
   ```

10. **Input step**: Interactive prompts for user input during workflow execution
    ```yaml
    steps:
      - analyze_code
      - input:
          name: get_user_feedback
          prompt: "Should we proceed with the refactoring? (yes/no)"
          type: confirm
      - input:
          name: review_changes
          prompt: "Enter your review comments"
          type: text
      - input:
          name: select_strategy
          prompt: "Choose optimization strategy"
          type: choice
          options:
            - "Performance optimization"
            - "Memory optimization"
            - "Code clarity"
      - input:
          name: api_configuration
          prompt: "Enter API key"
          type: password
    ```
    
    Input steps pause workflow execution to collect user input. They support several types:
    - `text`: Free-form text input (default if type not specified)
    - `confirm`: Yes/No confirmation prompts
    - `select`: Choice from a list of options
    - `password`: Masked input for sensitive data
    
    The user's input is stored in the workflow output using the step name as the key and can be accessed in subsequent steps via interpolation (e.g., `{{output.get_user_feedback}}`).

#### Step Configuration

Steps can be configured with various options to control their behavior:

```yaml
steps:
  - analyze_code           # Simple step reference
  - generate_report:       # Step with configuration
      model: gpt-4o        # Override the global model for this step
      print_response: true # Explicitly control output printing
      json: true           # Request JSON-formatted response
      params:              # Additional parameters for the API call
        temperature: 0.8
```

**Configuration options:**
- `model`: Override the workflow's default model for this specific step
- `print_response`: Control whether the step's response is included in the final output (default: `false`, except for the last step which defaults to `true` as of v0.3.1)
- `json`: Request a JSON-formatted response from the model
- `params`: Additional parameters passed to the model API (temperature, max_tokens, etc.)
- `path`: Custom directory path for the step's prompt files
- `coerce_to`: Type coercion for the step result (`:boolean`, `:llm_boolean`, `:iterable`)

**Automatic Last Step Output**: As of version 0.3.1, the last step in a workflow automatically has `print_response: true` unless explicitly configured otherwise. This ensures that newcomers to Roast see output from their workflows by default.

#### Shared Configuration

Roast supports sharing common configuration and steps across multiple workflows using a `shared.yml` file.

1. Place a `shared.yml` file one level above your workflow directory
2. Define YAML anchors for common configurations like tools, models or steps
3. Reference these anchors in your workflow files using YAML alias syntax

**Example structure:**
```
my_project/
├── shared.yml          # Common configuration anchors
└── workflows/
    ├── analyze_code.yml
    ├── generate_docs.yml
    └── test_suite.yml
```

**Example `shared.yml`:**
```yaml
# Define common tools
standard_tools: &standard_tools
  - Roast::Tools::Grep
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile
  - Roast::Tools::SearchFile
```

**Using in workflows:**
```yaml
name: Code Analysis Workflow
tools: *standard_tools         # Reference shared tools

steps:
  ...
```

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
- `-f, --file-storage`: Use filesystem storage for sessions instead of SQLite (default: SQLite)

#### Workflow Validation

Roast provides a `validate` command to check workflow configuration files for errors and potential issues before execution:

```bash
# Validate a specific workflow
roast validate workflow.yml

# Validate a workflow in a subdirectory
roast validate my_workflow

# Validate with strict mode (treats warnings as errors)
roast validate workflow.yml --strict
```

The validator checks for:
- YAML syntax errors
- Missing required fields
- Invalid step references
- Circular dependencies
- Tool availability
- Prompt file existence
- Configuration consistency

This helps catch configuration errors early and ensures workflows will run smoothly.

#### Session Storage and Management

Roast uses SQLite by default for session storage, providing better performance and advanced querying capabilities. Sessions are automatically saved during workflow execution, capturing each step's state including conversation transcripts and outputs.

**Storage Options:**

```bash
# Use default SQLite storage (recommended)
roast execute workflow.yml

# Use legacy filesystem storage
roast execute workflow.yml --file-storage

# Set storage type via environment variable
ROAST_STATE_STORAGE=file roast execute workflow.yml
```

**Session Management Commands:**

```bash
# List all sessions
roast sessions

# Filter sessions by status
roast sessions --status waiting

# Filter sessions by workflow
roast sessions --workflow my_workflow

# Show sessions older than 7 days
roast sessions --older-than 7d

# Clean up old sessions
roast sessions --cleanup --older-than 30d

# View detailed session information
roast session <session_id>
```

#### Session Replay

The session replay feature allows you to resume workflows from specific steps, saving time during development and debugging:

```bash
# Resume from a specific step
roast execute workflow.yml -r step_name

# Resume from a specific step in a specific session
roast execute workflow.yml -r 20250507_123456_789:step_name
```

This feature is particularly useful when:
- Debugging specific steps in a long workflow
- Iterating on prompts without rerunning the entire workflow
- Resuming after failures in long-running workflows

**Storage Locations:**
- SQLite: `~/.roast/sessions.db` (configurable via `ROAST_SESSIONS_DB`)
- Filesystem: `.roast/sessions/` directory in your project

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

#### Dynamic API Tokens and URIs

Roast allows you to dynamically fetch attributes such as API token and URI base (to use with a proxy) via shell commands directly in your workflow configuration:

```yaml
# This will execute the shell command and use the result as the API token
api_token: $(print-token --key)

# For OpenAI (default)
api_token: $(echo $OPENAI_API_KEY)

# For OpenRouter (requires api_provider setting)
api_provider: openrouter
api_token: $(echo $OPENROUTER_API_KEY)

# Static Proxy URI
uri_base: https://proxy.example.com/v1

# Dynamic Proxy URI
uri_base: $(echo $AI_PROXY_URI_BASE)
```

This makes it easy to use environment-specific tokens without hardcoding credentials, especially useful in development environments or CI/CD pipelines. Alternatively, Roast will fall back to `OPENROUTER_API_KEY` or `OPENAI_API_KEY` environment variables based on the specified provider.


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

### Workflow Metadata

Roast workflows maintain a metadata store that allows steps to share structured data beyond the standard output hash. This is particularly useful for tracking state that needs to persist across steps but shouldn't be part of the conversation context.

#### Setting Metadata

Metadata can be set by custom Ruby steps that extend `BaseStep`:

```ruby
# workflow/analyze_codebase.rb
class AnalyzeCodebase < Roast::Workflow::BaseStep
   include Roast::Helpers::MetadataAccess
   
  def call
    # Perform analysis
    analysis_results = perform_deep_analysis
    
    # Store metadata for other steps to use
    workflow.metadata[name.to_s] ||= {}
    workflow.metadata[name.to_s]["total_files"] = analysis_results[:file_count]
    workflow.metadata[name.to_s]["complexity_score"] = analysis_results[:complexity]
    workflow.metadata[name.to_s]["analysis_id"] = SecureRandom.uuid
    
    # Return the normal output for the conversation
    "Analyzed #{analysis_results[:file_count]} files with average complexity of #{analysis_results[:complexity]}"
  end
  
  private
  
  def perform_deep_analysis
    # Your analysis logic here
    { file_count: 42, complexity: 7.5 }
  end
end
```

#### Accessing Metadata

Metadata from previous steps can be accessed in:

1. **Custom Ruby steps:**
```ruby
class GenerateReport < Roast::Workflow::BaseStep
  def call
    # Access metadata from a previous step
    total_files = workflow.metadata.dig("analyze_codebase", "total_files")
    complexity = workflow.metadata.dig("analyze_codebase", "complexity_score")
    
    "Generated report for #{total_files} files with complexity score: #{complexity}"
  end
end
```

2. **Workflow configuration via interpolation:**
```yaml
steps:
  - analyze_codebase
  - validate_threshold
  - generate_report

# Use metadata in step configuration
validate_threshold:
  if: "{{metadata.analyze_codebase.complexity_score > 8.0}}"
  then:
    - send_alert
    - create_ticket
  else:
    - mark_as_passed

# Pass metadata to command steps
send_alert:
  $(slack-notify "High complexity detected: {{metadata.analyze_codebase.complexity_score}}")
```

3. **Prompt templates (ERB):**
```erb
# In analyze_codebase/output.txt
Analysis Summary:
Files analyzed: <%= workflow.metadata.dig(name.to_s, "total_files") %>
Complexity score: <%= workflow.metadata.dig(name.to_s, "complexity_score") %>
Analysis ID: <%= workflow.metadata.dig(name.to_s, "analysis_id") %>
```

#### Metadata Best Practices

- **Use metadata for data that shouldn't be in the conversation** 
- **Don't duplicate output data:** Metadata complements the output hash, it doesn't replace it

The metadata system is particularly useful for:
- Tracking session or transaction IDs across multiple steps
- Storing configuration or state that tools need to access
- Passing data between steps without cluttering the AI conversation
- Implementing complex conditional logic based on computed values

### Instrumentation

Roast provides extensive instrumentation capabilities using ActiveSupport::Notifications. You can monitor workflow execution, track AI model usage, measure performance, and integrate with external monitoring systems. [Read the full instrumentation documentation](docs/INSTRUMENTATION.md).

### Built-in Tools

Roast provides several built-in tools that you can use in your workflows:

#### Tool Configuration

Tools can be configured using a hash format in your workflow YAML:

```yaml
tools:
  - Roast::Tools::ReadFile        # No configuration needed
  - Roast::Tools::Cmd:             # With configuration
      allowed_commands:
        - git
        - npm
        - yarn
  - Roast::Tools::CodingAgent:     # Optional configuration
      coding_agent_command: claude --model opus -p --allowedTools "Bash, Glob, Grep, LS, Read"
      model: opus                  # Model to use for all CodingAgent invocations
      retries: 3                   # Number of automatic retries on failure (default: 0)
```

Currently supported configurations:
- `Roast::Tools::Cmd` via `allowed_commands`: restricts which commands can be executed (defaults to: `pwd`, `find`, `ls`, `rake`, `ruby`, `dev`, `mkdir`)
- `Roast::Tools::CodingAgent` via:
  - `coding_agent_command`: customizes the Claude Code CLI command used by the agent
  - `model`: sets the model for all CodingAgent invocations (e.g., `opus`, `sonnet`)
  - `retries`: number of times to automatically retry if the agent encounters an error (default: 0, no retries)

##### Cmd Tool Configuration

The `Cmd` tool's `allowed_commands` can be configured in two ways:

**1. Simple String Format** (uses default descriptions):
```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - git
```

**2. Hash Format with Custom Descriptions**:
```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - name: git
          description: "git CLI - version control system with subcommands like status, commit, push"
        - name: npm
          description: "npm CLI - Node.js package manager with subcommands like install, run"
        - name: docker
          description: "Docker CLI - container platform with subcommands like build, run, ps"
```

Custom descriptions help the LLM understand when and how to use each command, making your workflows more effective.

### Step-Level Tool Filtering

You can restrict which tools are available to specific steps using the `available_tools` configuration:

```yaml
# Define all tools globally
tools:
  - Roast::Tools::Grep
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - echo

# Configure steps with specific tool access
explore_directory:
  available_tools:
    - pwd
    - ls

analyze_files:
  available_tools:
    - grep
    - read_file

write_summary:
  available_tools:
    - write_file
    - echo
```

This feature provides:
- **Security**: Each step only has access to the tools it needs
- **Performance**: Reduces the tool list sent to the LLM
- **Clarity**: Makes tool usage explicit for each step

Key points:
- Use snake_case tool names (e.g., `read_file` for `Roast::Tools::ReadFile`)
- For `Cmd` tool, use the specific command names (e.g., `pwd`, `ls`)
- When `available_tools` is not specified, all tools remain available (backward compatible)
- Empty array (`available_tools: []`) means no tools for that step

See the [available_tools_demo](examples/available_tools_demo/) for a complete example.

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

Executes shell commands with configurable restrictions. By default, only allows specific safe commands.

```ruby
# Execute allowed commands (pwd, find, ls, rake, ruby, dev, mkdir by default)
pwd(args: "-L")
ls(args: "-la")
ruby(args: "-e 'puts RUBY_VERSION'")

# Or use the legacy cmd function with full command
cmd(command: "ls -la")
```

- Commands are registered as individual functions based on allowed_commands configuration
- Default allowed commands: pwd, find, ls, rake, ruby, dev, mkdir
- Each command has built-in descriptions to help the LLM understand usage
- Configurable via workflow YAML (see Tool Configuration section)

#### Bash

Executes shell commands without restrictions. **⚠️ WARNING: Use only in trusted environments!**

```ruby
# Execute any command - no restrictions
bash(command: "curl https://api.example.com | jq '.data'")

# Complex operations with pipes and redirects
bash(command: "find . -name '*.log' -mtime +30 -delete")

# System administration tasks
bash(command: "ps aux | grep ruby | awk '{print $2}'")
```

- **No command restrictions** - full shell access
- Designed for prototyping and development environments
- Logs warnings by default (disable with `ROAST_BASH_WARNINGS=false`)
- Should NOT be used in production or untrusted contexts
- See `examples/bash_prototyping/` for usage examples

#### CodingAgent

Creates a specialized agent for complex coding tasks or long-running operations.

```ruby
# Basic usage
coding_agent(
  prompt: "Refactor the authentication module to use JWT tokens",
  include_context_summary: true,  # Include workflow context in the agent prompt
  continue: true                  # Continue from previous agent session
)

# With automatic retries on failure
coding_agent(
  prompt: "Implement complex feature with error handling",
  retries: 3  # Retry up to 3 times if the agent encounters errors
)
```

- Delegates complex tasks to a specialized coding agent (Claude Code)
- Useful for tasks that require deep code understanding or multi-step changes
- Can work across multiple files and languages
- Supports automatic retries on transient failures (network issues, API errors)
- Retries can be configured globally (see Tool Configuration) or per invocation

### MCP (Model Context Protocol) Tools

Roast supports MCP tools, allowing you to integrate external services and tools through the Model Context Protocol standard. MCP enables seamless connections to databases, APIs, and specialized tools.

#### Configuring MCP Tools

MCP tools are configured in the `tools` section of your workflow YAML alongside traditional Roast tools:

```yaml
tools:
  # Traditional Roast tools
  - Roast::Tools::ReadFile

  # MCP tools with SSE (Server-Sent Events)
  - Documentation:
      url: https://gitmcp.io/myorg/myrepo/docs
      env:
        - "Authorization: Bearer {{ENV['API_TOKEN']}}"

  # MCP tools with stdio
  - GitHub:
      command: npx
      args: ["-y", "@modelcontextprotocol/server-github"]
      env:
        GITHUB_PERSONAL_ACCESS_TOKEN: "{{ENV['GITHUB_TOKEN']}}"
      only:
        - search_repositories
        - get_issue
        - create_issue
```

#### SSE MCP Tools

Connect to HTTP endpoints implementing the MCP protocol:

```yaml
- Tool Name:
    url: https://example.com/mcp-endpoint
    env:
      - "Authorization: Bearer {{resource.api_token}}"
    only: [function1, function2]  # Optional whitelist
    except: [function3]           # Optional blacklist
```

#### Stdio MCP Tools

Connect to local processes implementing the MCP protocol:

```yaml
- Tool Name:
    command: docker
    args: ["run", "-i", "--rm", "ghcr.io/example/mcp-server"]
    env:
      API_KEY: "{{ENV['API_KEY']}}"
```

See the [MCP tools example](examples/mcp/) for complete documentation and more examples.

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

### Pre/Post Processing Framework

Roast supports pre-processing and post-processing phases for workflows. This enables powerful workflows that need setup/teardown or result aggregation across all processed files.

#### Overview

- **Pre-processing**: Steps executed once before any targets are processed
- **Post-processing**: Steps executed once after all targets have been processed
- **Shared state**: Pre-processing results are available to all subsequent steps
- **Result aggregation**: Post-processing has access to all workflow execution results
- **Single-target support**: Pre/post processing works with single-target workflows too
- **Output templates**: Post-processing supports `output.txt` templates for custom formatting

#### Configuration

```yaml
name: optimize_tests
model: gpt-4o
target: "test/**/*_test.rb"

# Pre-processing steps run once before any test files
pre_processing:
  - gather_baseline_metrics
  - setup_test_environment

# Main workflow steps run for each test file
steps:
  - analyze_test
  - improve_coverage
  - optimize_performance

# Post-processing steps run once after all test files
post_processing:
  - aggregate_results
  - generate_report
  - cleanup_environment
```

#### Directory Structure

Pre and post-processing steps follow the same conventions as regular steps but are organized in their own directories:

```
workflow.yml
pre_processing/
  ├── gather_baseline_metrics/
  │   └── prompt.md
  └── setup_test_environment/
      └── prompt.md
analyze_test/
  └── prompt.md
improve_coverage/
  └── prompt.md
optimize_performance/
  └── prompt.md
post_processing/
  ├── output.txt
  ├── aggregate_results/
  │   └── prompt.md
  ├── generate_report/
  │   └── prompt.md
  └── cleanup_environment/
      └── prompt.md
```

#### Data Access

**Pre-processing results in target workflows:**

Target workflows have access to pre-processing results through the `pre_processing_data` variable with dot notation:

```erb
# In a target workflow step prompt
The baseline metrics from pre-processing:
<%= pre_processing_data.gather_baseline_metrics %>

Environment setup details:
<%= pre_processing_data.setup_test_environment %>
```

**Post-processing data access:**

Post-processing steps have access to:

- `pre_processing`: Direct access to pre-processing results with dot notation
- `targets`: Hash of all target workflow results, keyed by file paths

Example post-processing prompt:
```markdown
# Generate Summary Report

Based on the baseline metrics:
<%= pre_processing.gather_baseline_metrics %>

Environment configuration:
<%= pre_processing.setup_test_environment %>

And the results from processing all files:
<% targets.each do |file, target| %>
File: <%= file %>
Analysis results: <%= target.output.analyze_test %>
Coverage improvements: <%= target.output.improve_coverage %>
Performance optimizations: <%= target.output.optimize_performance %>
<% end %>

Please generate a comprehensive summary report showing:
1. Overall improvements achieved
2. Files with the most significant changes
3. Recommendations for further optimization
```

#### Output Templates

Post-processing supports custom output formatting using ERB templates. Create an `output.txt` file in your `post_processing` directory to format the final workflow output:

```erb
# post_processing/output.txt
=== Workflow Summary Report ===
Generated at: <%= Time.now.strftime("%Y-%m-%d %H:%M:%S") %>

Environment: <%= pre_processing.setup_test_environment %>

Files Processed: <%= targets.size %>

<% targets.each do |file, target| %>
- <%= file %>: <%= target.output.analyze_test %>
<% end %>

<%= output.generate_report %>
===============================
```

The template has access to:
- `pre_processing`: All pre-processing step outputs with dot notation
- `targets`: Hash of all target workflow results with dot notation (each target has `.output` and `.final_output`)
- `output`: Post-processing step outputs with dot notation

#### Use Cases

This pattern is ideal for:

- **Code migrations**: Setup migration tools, process files, generate migration report
- **Test optimization**: Baseline metrics, optimize tests, aggregate improvements
- **Documentation generation**: Analyze codebase, generate docs per module, create index
- **Dependency updates**: Check versions, update files, verify compatibility
- **Security audits**: Setup scanners, check each file, generate security report
- **Performance analysis**: Establish baselines, analyze components, summarize findings

See the [pre/post processing example](examples/pre_post_processing) for a complete working demonstration.


## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake` to run the tests and linter. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
