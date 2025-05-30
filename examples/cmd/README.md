# Command Tool Examples

Learn how to execute system commands in your Roast workflows using the Cmd tool. This example demonstrates how to define allowed commands and use them as functions within your workflows.

## Overview

The `Cmd` tool allows you to define a list of approved system commands that can be executed by the AI. Each allowed command is treated as a distinct function, providing several benefits:

- **Security**: Only explicitly allowed commands can be run, preventing unauthorized system access.
- **Clarity**: Each command has a clear, defined purpose within the workflow.
- **Intelligent Usage**: Custom descriptions can be provided to help the AI choose the correct command for a given task.

## Configuration

You can configure the `Cmd` tool in your workflow YAML file.

### Basic Configuration

List the commands that the AI is allowed to execute:

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - echo
```

Each command listed here (`pwd`, `ls`, `echo`) becomes a function the AI can call. For example, the AI can call `pwd()` to get the current directory, or `ls(args: "-la")` to list files.

### Enhanced Configuration with Descriptions

For more complex commands or to provide better guidance to the AI, you can include a description:

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - name: git
          description: "git CLI - version control system (e.g., git status, git log)"
        - name: npm
          description: "npm CLI - Node.js package manager (e.g., npm install, npm run)"
        - name: docker
          description: "Docker CLI - container platform (e.g., docker ps, docker run)"
```
These descriptions help the AI understand the purpose of each command and its common subcommands or arguments.

## How It Works

When the `Cmd` tool is configured, each entry in `allowed_commands` is registered as a function available to the AI.

- `pwd` becomes `pwd()`
- `ls` becomes `ls(args: <string>)`
- `git` (with a description) becomes `git(args: <string>)`

The AI can then choose to call these functions with appropriate arguments (passed via the `args` parameter) to accomplish its tasks.

## Example Workflows

This directory contains several example workflows demonstrating different uses of the `Cmd` tool:

- **`basic_workflow.yml`**: Introduces simple command execution.
- **`explorer_workflow.yml`**: Uses commands to navigate and understand a project structure.
- **`dev_workflow.yml`**: Showcases how descriptions guide the AI in selecting tools for development-related tasks.

## Running the Examples

To run an example workflow:
```bash
bin/roast execute examples/cmd/NAME_OF_WORKFLOW.yml
```
For instance:
```bash
bin/roast execute examples/cmd/basic_workflow.yml
```

## Security

Explicitly defining `allowed_commands` is crucial for security:
- You maintain full control over which system commands the AI can execute.
- It creates self-documenting configurations, making workflows safer and more predictable.

## Best Practices

- **Start Simple**: Begin with basic commands like `pwd` and `ls`.
- **Use Descriptions for Clarity**: Provide descriptions for commands that are not universally understood or have complex arguments/subcommands. This helps both the AI and human readers.
- **Scope Appropriately**: Only allow commands that are necessary for the workflow's intended purpose.

## Why Use Custom Descriptions?

Custom descriptions are particularly useful when:
- Dealing with domain-specific or less common commands.
- Disambiguating between commands with similar names or overlapping functionality.
- Guiding the AI to make more informed decisions about tool selection.

Good descriptions enhance the AI's ability to use commands effectively and make your workflows more robust.
