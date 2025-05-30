# Tool Configuration Example

This example demonstrates how to configure tools with specific settings in Roast workflows.

## Overview

Starting with this update, Roast supports configuring tools with specific settings directly in the workflow YAML file. This is particularly useful for tools like `Roast::Tools::Cmd` where you might want to restrict which commands can be executed.

## Configuration Syntax

Tools can be configured in two ways:

### 1. Simple String Format (No Configuration)
```yaml
tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::WriteFile
  - Roast::Tools::Grep
```

### 2. Hash Format (With Configuration)
```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - ls
        - pwd
        - echo
```

### 3. Mixed Format
You can mix both formats in the same workflow:

```yaml
tools:
  - Roast::Tools::ReadFile
  - Roast::Tools::Cmd:
      allowed_commands:
        - ls
        - pwd
        - ruby
        - sed
  - Roast::Tools::WriteFile
  - Roast::Tools::SearchFile
```

## Example: Configuring Allowed Commands

The `Roast::Tools::Cmd` tool now supports an `allowed_commands` configuration that restricts which commands can be executed:

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - ls
        - pwd
        - echo
        - cat
        - ruby
        - rake
```

### Enhanced Command Configuration with Descriptions

You can also provide custom descriptions for commands to help the LLM understand their purpose:

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - ls
        - pwd
        - name: echo
          description: "echo command - output text to stdout, supports > for file redirection"
        - name: cat
          description: "cat command - display file contents, concatenate files, works with pipes"
```

This mixed format allows you to:
- Use simple strings for commands with good default descriptions
- Provide custom descriptions for commands that need more context
- Help the LLM make better decisions about which command to use

With this configuration:
- ✅ `ls -la` will work
- ✅ `echo "Hello World"` will work
- ❌ `rm file.txt` will be rejected (not in allowed list)
- ❌ `git status` will be rejected (not in allowed list)

## Default Behavior

If no configuration is provided for `Roast::Tools::Cmd`, it uses the default allowed commands:
- pwd
- find
- ls
- rake
- ruby
- dev
- mkdir

## Running the Example

To run this example workflow:

```bash
bin/roast execute examples/tool_config_example/workflow.yml
```

The workflow will validate the tool configuration by executing various commands and demonstrating which ones are allowed and which are rejected based on the configuration.
