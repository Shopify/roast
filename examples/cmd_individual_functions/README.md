# Command Functions in Roast

Learn how to execute system commands in your Roast workflows using individual command functions.

## Overview

When you configure the `Cmd` tool with specific allowed commands, each command becomes its own function that the AI can call. This makes your workflows more secure and easier to understand.

## How It Works

### 1. Configure Your Commands

In your workflow YAML, specify which commands the AI can use:

```yaml
tools:
  - Roast::Tools::Cmd:
      allowed_commands:
        - pwd      # Print working directory
        - ls       # List files
        - echo     # Display text
        - git      # Version control
        - mkdir    # Create directories
        - cat      # Display file contents
```

### 2. Use Command Functions

Each allowed command becomes a function the AI can call:

- `pwd()` - Shows the current directory
- `ls(args: "-la")` - Lists files with options
- `echo(args: "Hello!")` - Displays messages
- `git(args: "status")` - Runs git commands
- `mkdir(args: "-p path/to/dir")` - Creates directories
- `cat(args: "filename.txt")` - Shows file contents

## Example Workflows

### 1. Basic Commands (`workflow.yml`)
A simple introduction to using command functions.

```bash
bundle exec roast execute examples/cmd_individual_functions/workflow.yml
```

### 2. Exploring Your Project (`exploration_workflow.yml`)
Learn how to navigate and examine your project structure.

```bash
bundle exec roast execute examples/cmd_individual_functions/exploration_workflow.yml
```

### 3. Building a Project (`project_builder_workflow.yml`)
See how to create a complete project structure using command functions.

```bash
bundle exec roast execute examples/cmd_individual_functions/project_builder_workflow.yml
```

## Directory Structure

Each workflow step lives in its own directory with a `prompt.md` file:

```
examples/cmd_individual_functions/
├── workflow.yml
├── exploration_workflow.yml
├── project_builder_workflow.yml
├── basic_commands/
│   └── prompt.md
├── explore_project/
│   └── prompt.md
├── check_git_status/
│   └── prompt.md
├── create_project/
│   └── prompt.md
└── verify_project/
    └── prompt.md
```

## Security Benefits

By explicitly listing allowed commands, you:
- Control exactly what the AI can execute
- Prevent unauthorized system access
- Make workflows more predictable
- Create self-documenting configurations

## Tips for New Users

1. **Start Small**: Begin with basic commands like `pwd` and `ls`
2. **Be Specific**: Each command must be explicitly allowed in your configuration
3. **Use Arguments**: Pass options using the `args` parameter
4. **Check Output**: Command functions return the full output including exit status

## Common Patterns

### Checking Your Location
```yaml
allowed_commands:
  - pwd
  - ls
```

### Working with Git
```yaml
allowed_commands:
  - git
  - ls
  - cat
```

### Building Projects
```yaml
allowed_commands:
  - mkdir
  - echo
  - ls
```

## Extending Your Toolkit

As you become comfortable with basic commands, you can add more to your allowed list. Just remember that each command you add increases what the AI can do in your system, so add them thoughtfully.
