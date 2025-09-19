# Roast TUI LLM Client

A complete OpenAI API client implementation for Roast TUI with full function/tool calling support, streaming responses, and parallel tool execution.

## Features

- **Full OpenAI API Compatibility**: Works with OpenAI and any OpenAI-compatible endpoints
- **Function/Tool Calling**: Complete implementation of OpenAI's function calling API
- **Streaming Support**: Real-time streaming of responses with CLI-UI integration
- **Parallel Tool Execution**: Execute multiple tools concurrently for better performance
- **Session Management**: Track and manage conversation history
- **Configurable**: Support for custom endpoints, models, and parameters
- **Built-in Tools**: File operations, shell commands, and HTTP requests
- **Error Handling**: Automatic retries with exponential backoff

## Installation

The TUI module is included in the Roast gem. No additional installation required.

## Configuration

### Environment Variables

```bash
export OPENAI_API_KEY="your-api-key"
export OPENAI_BASE_URL="https://api.openai.com/v1"  # Optional, for custom endpoints
export OPENAI_MODEL="gpt-4-turbo-preview"           # Optional, default model
```

### Programmatic Configuration

```ruby
require "roast/tui/llm_client"

# Basic configuration
client = Roast::TUI::LLMClient.new(
  api_key: "your-api-key",
  base_url: "https://api.openai.com/v1",
  model: "gpt-4-turbo-preview"
)

# With custom configuration
config = Roast::TUI::Configuration.new
config.temperature = 0.8
config.max_tokens = 2000
config.parallel_tools = true
```

## Usage Examples

### Basic Chat Completion

```ruby
messages = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "What is Ruby on Rails?" }
]

response = client.chat_completion(messages)
puts response.content
puts "Tokens used: #{response.total_tokens}"
```

### Streaming Responses

```ruby
client.chat_completion(messages, stream: true) do |chunk|
  if chunk["choices"]&.first&.dig("delta", "content")
    print chunk["choices"].first["delta"]["content"]
  end
end
```

### Tool/Function Calling

```ruby
# Tools are automatically registered and available
messages = [
  { role: "user", content: "What files are in the current directory?" }
]

response = client.chat_with_tools(messages) do |event|
  case event[:type]
  when :tool_start
    puts "Calling tool: #{event[:name]}"
  when :tool_complete
    puts "Tool result: #{event[:result]}"
  end
end

puts response.content
```

### Custom Tool Registration

```ruby
registry = Roast::TUI::ToolRegistry.new

registry.register(
  name: "calculate",
  description: "Perform calculations",
  parameters: {
    type: "object",
    properties: {
      expression: { type: "string", description: "Math expression" }
    },
    required: ["expression"]
  }
) do |args|
  eval(args["expression"]).to_s  # Use safe math parser in production
end

client = Roast::TUI::LLMClient.new(tool_registry: registry)
```

### Session Management

```ruby
session = Roast::TUI::SessionManager.new

# Add messages to session
session.add_system_message("You are a helpful assistant")
session.add_user_message("Hello!")
session.add_assistant_message("Hi! How can I help you?")

# Export conversation
json_data = session.export(format: :json)
markdown = session.export(format: :markdown)

# Save and load sessions
session.save_to_file("conversation.json")
loaded_session = Roast::TUI::SessionManager.new
loaded_session.load_from_file("conversation.json")

# Get conversation summary
summary = session.conversation_summary
puts "Total messages: #{summary[:message_count]}"
puts "Estimated tokens: #{summary[:total_tokens]}"
```

### Streaming with Tools

```ruby
client.stream_with_tools(messages) do |event|
  case event[:type]
  when :chunk
    # Stream content as it arrives
    if event[:data]["choices"]&.first&.dig("delta", "content")
      print event[:data]["choices"].first["delta"]["content"]
    end
  when :tool_start
    puts "\nCalling #{event[:name]}..."
  when :tool_result
    puts "Tool completed!"
  end
end
```

## Built-in Tools

The client comes with these tools pre-registered:

1. **read_file**: Read file contents
2. **write_file**: Write content to files
3. **list_directory**: List directory contents
4. **execute_command**: Run shell commands
5. **http_request**: Make HTTP requests

## Architecture

### Components

- **LLMClient**: Main client for API interactions
- **LLMResponse**: Response parsing and handling
- **ToolRegistry**: Tool registration and execution
- **Configuration**: Settings management
- **SessionManager**: Conversation tracking

### Streaming Architecture

The streaming implementation uses Server-Sent Events (SSE) to process responses in real-time. The `StreamAccumulator` class handles partial tool calls and content assembly.

### Parallel Tool Execution

When multiple tools are called, they can be executed in parallel using Ruby's Concurrent gem. This significantly improves performance for workflows that need to call multiple independent tools.

## Error Handling

The client implements automatic retry logic for:
- Rate limiting (429)
- Server errors (500, 502, 503, 504)
- Network timeouts

Retries use exponential backoff with configurable max retries and delays.

## Testing

Run the verification script to test all components:

```bash
ruby lib/roast/tui/verify.rb
```

Run the example demonstrations:

```bash
ruby lib/roast/tui/example.rb
```

## API Compatibility

The client is compatible with:
- OpenAI API (GPT-3.5, GPT-4, etc.)
- Anthropic Claude (via adapter)
- Local models (Ollama, LocalAI)
- Any OpenAI-compatible endpoint

## Performance Considerations

- Tool execution can be parallelized for better performance
- Stream buffering is configurable for optimal throughput
- Session management includes token estimation for context management
- Automatic message truncation when approaching token limits

## Security

- API keys are never logged or saved to disk
- File operations are sandboxed to prevent directory traversal
- Shell command execution requires explicit opt-in
- All external requests use HTTPS by default

## Contributing

When adding new features to the TUI module:
1. Add comprehensive tests
2. Update this documentation
3. Ensure compatibility with existing tools
4. Follow Ruby best practices and Roast conventions