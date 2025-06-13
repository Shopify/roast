# Roast MCP Server

The Roast MCP (Model Context Protocol) Server allows you to expose your Roast workflows as tools that can be called by AI assistants like Claude, ChatGPT, or any other MCP-compatible client.

## What is MCP?

Model Context Protocol (MCP) is an open standard that enables AI assistants to interact with external tools and data sources. By running a Roast MCP server, you can make your workflows available to AI assistants, allowing them to execute complex tasks defined in your workflow files.

## Starting the MCP Server

To start the MCP server:

```bash
bin/roast mcp-server [WORKFLOW_DIRS...]
```

### Arguments and Options

- **Positional arguments**: Directories to search for workflows (recommended for Claude config)
- `--workflows` or `-w`: Additional directories to search for workflows (can be used multiple times)
- `--log` or `-l`: Log to a file instead of stderr

### Examples

```bash
# Start server with default workflow directories
bin/roast mcp-server

# Add workflow directories as arguments (best for Claude/MCP client config)
bin/roast mcp-server /path/to/workflows1 /path/to/workflows2

# Search for workflows in specific directories using flags
bin/roast mcp-server -w ~/my-workflows -w ~/team-workflows

# Mix arguments and flags
bin/roast mcp-server ~/my-workflows -w ~/team-workflows

# Log to a file
bin/roast mcp-server ~/my-workflows --log mcp-server.log
```

## Default Workflow Directories

The MCP server automatically searches for workflows in:

1. Directories specified with the `--workflows` option
2. `./workflows/` in the current directory
3. `./roast_workflows/` in the current directory
4. Any `.yml` files in the current directory that contain `steps:`

## How Workflows are Exposed

Each workflow becomes a tool with:

- **Tool name**: `roast_` prefix + workflow name (spaces replaced with underscores, lowercase)
- **Description**: The workflow's description field, or a default description
- **Input parameters**: Automatically detected from:
  - The workflow's `target` field (if present)
  - The workflow's `each` field (adds `file` parameter)
  - Any `{{variable}}` interpolations (mustache syntax)
  - Any `<%= workflow.variable %>` interpolations (ERB syntax)
  - Any `ENV['ROAST_VARIABLE']` references
  - A default `file` parameter if no other parameters are detected

### Example 1: Target-based workflow

Given this workflow in `workflows/analyze_code.yml`:

```yaml
name: Analyze Code
description: Analyzes code quality and suggests improvements
target: "*.rb"
steps:
  - analyze: |
      Analyze the {{language}} code in {{ENV['ROAST_TARGET']}}
      Focus on {{focus_area}} improvements
```

The MCP server will expose it as:

- **Tool name**: `roast_analyze_code`
- **Parameters**:
  - `target`: Target file or input for the workflow
  - `language`: Value for {{language}} in the workflow
  - `focus_area`: Value for {{focus_area}} in the workflow

### Example 2: File-based workflow (grading example)

Given this workflow in `workflows/grade_tests.yml`:

```yaml
name: Grade Tests
description: Grades test quality and coverage
each: 'git ls-files | grep _test.rb'
steps:
  - analyze: |
      Grade the test file <%= workflow.file %>
      Check for <%= workflow.criteria %> quality
```

The MCP server will expose it as:

- **Tool name**: `roast_grade_tests`
- **Parameters**:
  - `file`: File to process with this workflow
  - `criteria`: Value for workflow.criteria in the workflow

## Using with Claude Desktop

To use your Roast workflows with Claude Desktop, you have two options:

### Option 1: Using the dedicated MCP wrapper (Recommended)

```json
{
  "mcpServers": {
    "roast": {
      "command": "/path/to/roast/bin/roast-mcp",
      "args": ["/path/to/your/workflows"],
      "env": {
        "OPENAI_API_KEY": "your-api-key"
      }
    }
  }
}
```

Or using environment variables instead of args:

```json
{
  "mcpServers": {
    "roast": {
      "command": "/path/to/roast/bin/roast-mcp",
      "env": {
        "OPENAI_API_KEY": "your-api-key",
        "ROAST_WORKFLOW_DIRS": "/path/to/workflows1:/path/to/workflows2",
        "ROAST_LOG_LEVEL": "INFO"
      }
    }
  }
}
```

### Option 2: Using the main roast command

```json
{
  "mcpServers": {
    "roast": {
      "command": "/path/to/roast/bin/roast",
      "args": ["mcp-server", "/path/to/your/workflows"],
      "env": {
        "OPENAI_API_KEY": "your-api-key"
      }
    }
  }
}
```

Note: The `roast-mcp` wrapper is recommended as it ensures a clean stdout for the MCP protocol. Claude's MCP configuration works best with positional arguments rather than flags, so specify workflow directories directly in the `args` array.

## Environment Variables

### MCP Server Configuration

The MCP server can be configured using environment variables:

- `ROAST_WORKFLOW_DIRS`: Colon-separated list of directories to search for workflows (e.g., `/path/to/workflows1:/path/to/workflows2`)
- `ROAST_LOG_LEVEL`: Set the log level (DEBUG, INFO, WARN, ERROR)

Example:
```bash
export ROAST_WORKFLOW_DIRS="/home/user/workflows:/opt/team-workflows"
export ROAST_LOG_LEVEL=DEBUG
bin/roast-mcp
```

### Workflow Execution

When workflows are executed through MCP, arguments are passed as environment variables:

- Named parameters become `ROAST_<PARAMETER_NAME>` (uppercase)
- The special `target` parameter is passed directly to the workflow

For example, calling the tool with `{"name": "John", "target": "file.txt"}` sets:
- `ENV['ROAST_NAME']` = "John"
- The workflow receives `file.txt` as its target

## Protocol Details

The Roast MCP server implements the Model Context Protocol with support for multiple versions:
- 2024-11-05 (primary)
- 2024-11-15
- 2025-03-26 (latest)
- 1.0, 1.0.0
- 0.1.0

The server supports all required MCP methods:

- `initialize`: Protocol handshake
- `tools/list`: List available workflows as tools
- `tools/call`: Execute a workflow
- `prompts/list`: List available prompts (returns empty - Roast uses workflows instead)
- `prompts/get`: Get a specific prompt (not applicable for Roast)
- `resources/list`: List available resources (returns empty - Roast doesn't expose resources)
- `resources/read`: Read a resource (not applicable for Roast)
- `ping`: Health check
- `shutdown`: Graceful shutdown
- `notifications/initialized`: Client ready notification

## Security Considerations

- The MCP server executes workflows with the same permissions as the user running the server
- Workflows can access the filesystem and execute commands based on their tool configuration
- Only expose workflows you trust to MCP clients
- Consider running the server with restricted permissions in production environments

## Troubleshooting

### Connection Failed Error (-32000)

If you get a "connection failed" error when using with Claude:

1. **Use the dedicated wrapper**: Try using `/path/to/roast/bin/roast-mcp` instead of the main roast command
2. **Check the logs**: Run the server manually to see any error messages:
   ```bash
   /path/to/roast/bin/roast mcp-server /path/to/workflows
   ```
3. **Verify paths**: Ensure all paths in your configuration are absolute paths
4. **Check Ruby/Bundler**: Make sure Ruby and all dependencies are properly installed:
   ```bash
   cd /path/to/roast && bundle install
   ```

### Workflows not discovered

- Check that your workflow files have a `.yml` extension
- Ensure workflows have a `steps:` section
- Verify the workflow directories exist and are readable
- Run with `--log` to see which directories are being searched

### Workflow execution errors

- Check the server logs (stderr or log file)
- Ensure required environment variables are set (e.g., `OPENAI_API_KEY`)
- Verify the workflow runs successfully with `bin/roast execute`

### MCP client connection issues

- Ensure the server is running on stdin/stdout (not a network port)
- Check that the MCP client is configured with the correct command path
- Verify the MCP protocol version is supported (2024-11-05, 2024-11-15, 2025-03-26, 1.0, 1.0.0, or 0.1.0)
- Make sure no output is sent to stdout before the MCP protocol starts
- Check the logs to see what protocol version your client is requesting