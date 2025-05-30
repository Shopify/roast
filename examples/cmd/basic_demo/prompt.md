# Basic Command Demonstration

You are demonstrating basic command functions. Execute several simple commands to show how the command tool system works.

**SPECIFIC TASKS:**
1. Show the current working directory: use `pwd`
2. List all files with details: use `ls -la`
3. Display celebratory message: use `echo "🎉 Command functions are working!"`
4. List examples directory: use `ls examples/`

**EFFICIENCY RULES:**
- Execute each command ONLY ONCE
- DO NOT repeat any command
- Follow the exact order above

Each command execution demonstrates how commands are called as functions in the workflow, with security enforced through the workflow's configuration.

RESPONSE FORMAT
Provide a summary of your command executions in JSON format:

<json>
{
  "demonstration_complete": true,
  "commands_executed": [
    {
      "command": "pwd",
      "purpose": "Show current working directory",
      "output_summary": "Current directory path"
    },
    {
      "command": "ls -la",
      "purpose": "List all files with details",
      "output_summary": "Directory listing with permissions and sizes"
    },
    {
      "command": "echo \"🎉 Command functions are working!\"",
      "purpose": "Display test message",
      "output_summary": "Success message displayed"
    },
    {
      "command": "ls examples/",
      "purpose": "List examples directory",
      "output_summary": "Contents of examples directory"
    }
  ],
  "conclusion": "Successfully demonstrated basic command functions with security constraints"
}
</json>
