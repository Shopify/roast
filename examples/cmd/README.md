# Command Tool Examples

Learn how to execute system commands in your Roast workflows using the Cmd tool. This example demonstrates basic command functions, custom descriptions, and best practices for secure command execution.

## Overview

When you configure the `Cmd` tool, each allowed command becomes its own function that the AI can call. This provides:
- **Security**: Only explicitly allowed commands can be executed
- **Clarity**: Each command is a distinct function with clear purpose
- **Intelligence**: Custom descriptions help the AI choose the right tool

## Configuration

### Basic Configuration

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - echo
```

### Enhanced Configuration with Descriptions

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd
        - ls
        - name: git
          description: "git CLI - version control system with subcommands like status, log, branch"
        - name: npm
          description: "npm CLI - Node.js package manager with subcommands like install, run"
        - name: docker
          description: "Docker CLI - container platform with subcommands like ps, run, build"
```

## How It Works

Each allowed command becomes a function:
- `pwd()` - Shows current directory
- `ls(args: "-la")` - Lists files with options
- `git(args: "status")` - Runs git commands
- `npm(args: "install")` - Manages packages

## Example Workflows

### 1. Basic Commands (`basic_workflow.yml`)
Introduction to command functions with simple commands.

### 2. Project Explorer (`explorer_workflow.yml`)
Navigate and understand your project structure using command functions.

### 3. Development Tools (`dev_workflow.yml`)
Advanced example showing how custom descriptions guide tool selection for development tasks.

## Running the Examples

```bash
# Basic command usage
bundle exec roast execute examples/cmd/basic_workflow.yml

# Project exploration
bundle exec roast execute examples/cmd/explorer_workflow.yml

# Development workflow with smart tool selection
bundle exec roast execute examples/cmd/dev_workflow.yml
```

## Security Benefits

By explicitly listing allowed commands:
- Control exactly what the AI can execute
- Prevent unauthorized system access
- Create self-documenting configurations
- Make workflows predictable and safe

## Best Practices

### 1. Start Simple
Begin with basic commands like `pwd` and `ls` to understand the pattern.

### 2. Use Descriptions for Context
Help the AI understand when to use each command:
```yaml
- name: curl
  description: "curl command - make HTTP requests with options like -X, -H, -d"
```

### 3. Group Related Commands
Organize commands by their purpose in your workflow.

### 4. Consider Your Environment
Only allow commands that make sense for your specific use case.

## Common Patterns

### File System Navigation
```yaml
allowed_commands:
  - pwd
  - ls
  - find
  - cat
```

### Development Workflow
```yaml
allowed_commands:
  - git
  - npm
  - docker
  - make
```

### System Information
```yaml
allowed_commands:
  - uname
  - whoami
  - date
  - env
```

## Tips

1. **Arguments**: Pass options using the `args` parameter
2. **Output**: Command functions return the full output including exit status
3. **Errors**: Commands not in the allowed list will be rejected
4. **Flexibility**: Mix simple strings and descriptive hashes as needed

## Why Use Custom Descriptions?

Custom descriptions are valuable when:
- Using domain-specific commands
- Working with similar commands that need disambiguation
- Creating workflows for specific teams or projects
- Helping the AI make better tool selection decisions

Good descriptions act as documentation for both the AI and human readers!
