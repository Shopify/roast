# CMD Cog Examples

These examples demonstrate the `cmd` cog's dual execution modes: shell commands and direct execution.

## Running Examples

```bash
bin/roast execute dsl/shell_commands.rb --executor dsl
bin/roast execute dsl/direct_execution.rb --executor dsl
bin/roast execute dsl/shell_vs_direct.rb --executor dsl
bin/roast execute dsl/working_directory_with_both.rb --executor dsl
```

## Examples Overview

### 1. `shell_commands.rb` - Shell Features

Demonstrates shell command execution with:

- Pipes: `git status | wc -l`
- Command substitution: `$(git branch)`
- Variable expansion: `$VAR`
- Redirects: `> /tmp/file.txt`
- For loops and complex shell syntax

**When to use:** You need shell features like pipes, redirects, or command substitution.

### 2. `direct_execution.rb` - Safe Execution

Demonstrates direct execution (array syntax) with:

- No shell interpretation
- Safe handling of special characters
- Protection from shell injection
- Literal argument passing

**When to use:** You have untrusted input or want to avoid shell interpretation.

### 3. `shell_vs_direct.rb` - Comparison

Side-by-side comparison showing:

- When to use shell (string syntax)
- When to use direct (array syntax)
- Security considerations
- Performance implications

**When to use:** Learning which approach fits your use case.

### 4. `working_directory_with_both.rb` - Working Directory

Demonstrates `working_directory` config with:

- Shell commands in different directories
- Direct execution in different directories
- Per-command directory scoping

**When to use:** You need to run commands in specific directories.

## Syntax Quick Reference

### Shell Command (String)

```ruby
cmd(:my_cmd) { "git status | wc -l" }
```

- ✅ Pipes, redirects, variables work
- ⚠️ Shell injection risk with untrusted input
- Uses: `sh -c "command"` under the hood

### Direct Execution (Array)

```ruby
cmd(:my_cmd) { ["git", "status", "--porcelain"] }
```

- ✅ Safe from shell injection
- ✅ Special characters treated as literals
- ❌ No pipes, redirects, or variables
- Uses: `Open3.popen3("git", "status", "--porcelain")` under the hood

### With Working Directory

```ruby
config do
  cmd(:in_tmp) { working_directory "/tmp" }
end

execute do
  cmd(:in_tmp) { "pwd" }  # Runs in /tmp
end
```

## Security Guidelines

**Use shell commands (string) when:**

- You control all input
- You need shell features
- Commands are static/trusted

**Use direct execution (array) when:**

- Handling user input
- Special characters should be literal
- Security is critical
- You don't need shell features

## Implementation Details

- Shell commands: `CommandRunner.execute(string)` → wraps with `sh -c`
- Direct execution: `CommandRunner.simple_execute(*args)` → direct `Open3.popen3`
- Both support `working_directory`, `timeout`, `stdin_content`, stream handlers
