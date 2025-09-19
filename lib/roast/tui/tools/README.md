# Roast TUI Tools - OpenCode Compatible Implementation

This directory contains OpenCode-compatible tool implementations for Roast TUI, providing a comprehensive set of tools for file operations, searching, system operations, and task management.

## Architecture

### Base Class (`base.rb`)
- Abstract base class for all tools
- Provides:
  - OpenAI function schema generation
  - Argument validation (type, enum, pattern)
  - Permission system (ask/allow/deny modes)
  - Error handling with custom exceptions
  - Execution statistics tracking
  - Parameter schema helper methods

### Tool Categories

#### File Operations (`file_operations.rb`)
- **read** - Read file contents with line numbers, image metadata, PDF text extraction
- **write** - Create/overwrite files with protection prompts
- **edit** - Smart file editing with multiple strategies:
  - simple - Basic string replacement
  - line - Line-by-line editing
  - block - Multi-line block replacement
  - regex - Regular expression based
  - whitespace_agnostic - Ignore whitespace differences
- **multiedit** - Batch multiple edits to a single file
- **glob** - File pattern matching with sorting
- **ls** - Directory listing with detailed info

#### Search Operations (`search_operations.rb`)
- **grep** - Ripgrep-powered content search
  - Regex support
  - File type/glob filtering
  - Context lines (before/after)
  - Multiple output modes (content/files/count)
  - Multiline matching support
- **find** - Locate files by name/path patterns
  - Size filtering
  - Modification time filtering
  - Depth limiting
  - Falls back to standard find if fd not available

#### System Operations (`system_operations.rb`)
- **bash** - Execute shell commands
  - Timeout support (up to 10 minutes)
  - Background execution mode
  - Working directory control
  - Environment variable injection
  - Output streaming in interactive mode
- **bash_output** - Retrieve output from background processes
  - Regex filtering
  - Incremental output retrieval
- **kill_bash** - Terminate background processes
- **webfetch** - Fetch and process web content
  - HTTP GET/POST support
  - Custom headers
  - Redirect following
  - HTML to text conversion

#### Task Management (`task_management.rb`)
- **todo** - Session task list management
  - Three states: pending, in_progress, completed
  - Priority levels: low, medium, high
  - Tag support for categorization
  - Automatic timestamp tracking
  - Statistics and completion metrics
  - Enforces single in-progress task rule

## Usage

### Registering Tools with a Registry

```ruby
require "roast/tui/tools"

# Create a registry with all tools
registry = Roast::TUI::Tools.create_registry

# Or register with existing registry
registry = ToolRegistry.new
Roast::TUI::Tools.register_all(registry)
```

### Using Individual Tools

```ruby
# Get a specific tool
read_tool = Roast::TUI::Tools.get_tool("read")

# Execute with arguments
result = read_tool.execute({
  "file_path" => "/path/to/file.rb",
  "limit" => 100
})

# Configure permissions
Roast::TUI::Tools.configure_permissions({
  "write" => :deny,
  "bash" => :ask,
  "read" => :allow
})
```

### Generating OpenAI Function Schemas

```ruby
# Get schemas for all tools
schemas = Roast::TUI::Tools.openai_tools_spec

# Use with OpenAI API
response = openai_client.chat(
  model: "gpt-4",
  messages: [...],
  tools: schemas,
  tool_choice: "auto"
)
```

## Tool Features

### Permission System
Each tool supports three permission modes:
- `:ask` - Prompt user for permission (default for dangerous operations)
- `:allow` - Always allow execution
- `:deny` - Always deny execution

### Parallel Safety
Tools declare whether they can be safely executed in parallel:
- Read operations: parallel safe
- Write/edit operations: not parallel safe
- System operations: generally not parallel safe

### Error Handling
- `ValidationError` - Invalid arguments or preconditions not met
- `PermissionDeniedError` - Permission denied by permission system
- All errors include helpful messages for debugging

### Argument Validation
- Required vs optional parameters
- Type checking (string, integer, boolean, array, object)
- Enum validation for restricted values
- Pattern matching for strings
- Range validation for numbers

## Integration with Roast TUI

These tools integrate seamlessly with the Roast TUI system:
1. Tools are registered with the ToolRegistry
2. LLM receives tool schemas via OpenAI format
3. LLM calls tools during conversation
4. Results are formatted with CLI::UI for display
5. Permission checks ensure user control

## Dependencies

Required gems:
- `cli-ui` - Terminal UI formatting
- `open3` - Process execution
- `fileutils` - File operations
- `pathname` - Path manipulation
- `net/http` - HTTP requests
- `json` - JSON parsing

Optional gems for enhanced functionality:
- `mini_magick` - Image metadata extraction
- `pdf-reader` - PDF text extraction

## Testing

Run the test suite:
```bash
bundle exec ruby -Itest test/roast/tui/tools_test.rb
```

## Future Enhancements

Potential additions:
- Git operations (status, diff, commit)
- Database query tools
- API client tools
- Cloud storage integration
- Container management
- Process monitoring tools