# Available Tools Demo

This example demonstrates the new `available_tools` feature in Roast, which allows you to limit which tools are available to specific steps in your workflow.

## Overview

The workflow consists of three steps, each with different tool restrictions:

1. **explore_directory**: Can only use `pwd` and `ls` to explore the directory
2. **analyze_files**: Can only use `grep` and `read_file` to analyze code
3. **write_summary**: Can only use `write_file` and `echo` to create a summary

## Benefits

- **Security**: Limits what each step can do, reducing the risk of unintended actions
- **Performance**: Reduces the tool list sent to the LLM, improving response time
- **Clarity**: Makes it explicit which tools are intended for each step

## Running the Example

```bash
# Run from the Roast project root
roast execute examples/available_tools_demo/workflow.yml

# Or if you're in the examples directory
cd examples/available_tools_demo
roast execute workflow.yml
```

## How It Works

In the `workflow.yml`, we define all available tools globally:

```yaml
tools:
  - Roast::Tools::Grep
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - git
        - echo
```

Then for each step, we specify which subset of tools should be available:

```yaml
explore_directory:
  available_tools:
    - pwd
    - ls
```

The LLM will only see and be able to use the tools specified in `available_tools` for that particular step.

## Validation

Roast validates that all tools in `available_tools` are actually included in the global tools list. If you specify an invalid tool, you'll get a helpful error message showing which tools are valid for your workflow.
