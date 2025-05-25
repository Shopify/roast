# Instrumentation Hooks in Roast

Roast provides built-in instrumentation hooks using ActiveSupport::Notifications, allowing you to track workflow execution, monitor performance, and integrate with your own monitoring systems.

## Overview

The instrumentation system emits events at key points during workflow execution:

- Workflow lifecycle (start, complete)
- Step execution (start, complete, error)
- Chat completion/AI calls (start, complete, error)
- Tool function execution

## Configuration

To add custom instrumentation, create Ruby files in your project's `.roast/initializers/` directory. These files will be automatically loaded during workflow startup.

Example structure:
```
your-project/
  ├── .roast/
  │   └── initializers/
  │       ├── logging.rb
  │       ├── metrics.rb
  │       └── monitoring.rb
  └── ...
```

## Available Events

### Workflow Events

- `roast.workflow.start` - Emitted when a workflow begins
  - Payload: `{ workflow_path:, options:, name: }`
  
- `roast.workflow.complete` - Emitted when a workflow completes
  - Payload: `{ workflow_path:, success:, execution_time: }`

### Step Events

- `roast.step.start` - Emitted when a step begins execution
  - Payload: `{ step_name: }`
  
- `roast.step.complete` - Emitted when a step completes successfully
  - Payload: `{ step_name:, success: true, execution_time:, result_size: }`
  
- `roast.step.error` - Emitted when a step encounters an error
  - Payload: `{ step_name:, error:, message:, execution_time: }`

### AI/Chat Completion Events

- `roast.chat_completion.start` - Emitted before an AI API call
  - Payload: `{ model:, parameters: }`
  
- `roast.chat_completion.complete` - Emitted after successful AI API call
  - Payload: `{ success: true, model:, parameters:, execution_time:, response_size: }`
  
- `roast.chat_completion.error` - Emitted when AI API call fails
  - Payload: `{ error:, message:, model:, parameters:, execution_time: }`

### Tool Execution Events

- `roast.tool.execute` - Emitted when a tool function is called
  - Payload: `{ function_name:, params: }`

- `roast.tool.complete` - Emitted when a tool function completes
  - Payload: `{ function_name:, execution_time:, cache_enabled: }`
  
- `roast.tool.error` - Emitted when a tool execution fails
  - Payload: `{ function_name:, error:, message:, execution_time: }`

## Example Usage

### Basic Logging

```ruby
# .roast/initializers/logging.rb
ActiveSupport::Notifications.subscribe(/roast\./) do |name, start, finish, id, payload|
  duration = finish - start
  puts "[#{name}] completed in #{duration.round(3)}s"
end
```

### Performance Monitoring

```ruby
# .roast/initializers/performance.rb
ActiveSupport::Notifications.subscribe("roast.step.complete") do |name, start, finish, id, payload|
  duration = finish - start
  if duration > 10.0
    puts "WARNING: Step '#{payload[:step_name]}' took #{duration.round(1)}s"
  end
end
```

### Integration with External Services

```ruby
# .roast/initializers/metrics.rb
ActiveSupport::Notifications.subscribe("roast.workflow.complete") do |name, start, finish, id, payload|
  duration = finish - start
  
  # Send to your metrics service
  MyMetricsService.track_event("workflow_execution", {
    workflow_path: payload[:workflow_path],
    duration: duration,
    success: payload[:success]
  })
end
```

### Internal Shopify Example

For the internal Shopify version, you can use these instrumentation hooks to track metrics with Monorail:

```ruby
# .roast/initializers/monorail.rb

# Track workflow execution
ActiveSupport::Notifications.subscribe("roast.workflow.start") do |name, start, finish, id, payload|
  Roast::Support::Monorail.track_command("run", {
    "workflow_path" => payload[:workflow_path],
    "options" => payload[:options],
    "name" => payload[:name]
  })
end

ActiveSupport::Notifications.subscribe("roast.workflow.complete") do |name, start, finish, id, payload|
  Roast::Support::Monorail.track_command("run_complete", {
    "workflow_path" => payload[:workflow_path],
    "success" => payload[:success],
    "execution_time" => payload[:execution_time]
  })
end

# Track AI model usage and performance
ActiveSupport::Notifications.subscribe("roast.chat_completion.complete") do |name, start, finish, id, payload|
  Roast::Support::Monorail.track_command("ai_usage", {
    "model" => payload[:model],
    "execution_time" => payload[:execution_time],
    "response_size" => payload[:response_size],
    "has_json" => payload[:parameters][:json] || false,
    "has_loop" => payload[:parameters][:loop] || false
  })
end

# Track tool execution and caching
ActiveSupport::Notifications.subscribe("roast.tool.complete") do |name, start, finish, id, payload|
  Roast::Support::Monorail.track_command("tool_usage", {
    "function_name" => payload[:function_name],
    "execution_time" => payload[:execution_time],
    "cache_enabled" => payload[:cache_enabled]
  })
end
```

See `examples/monorail_initializer.rb` for a complete example of Monorail integration.

## Best Practices

1. **Keep initializers focused**: Each initializer should handle a specific concern (logging, metrics, error reporting, etc.)

2. **Handle errors gracefully**: Wrap your subscriber code in error handling to prevent crashes:
   ```ruby
   ActiveSupport::Notifications.subscribe("roast.workflow.start") do |name, start, finish, id, payload|
     begin
       # Your instrumentation code here
     rescue => e
       $stderr.puts "Instrumentation error: #{e.message}"
     end
   end
   ```

3. **Avoid blocking operations**: Instrumentation should be fast and non-blocking. For heavy operations, consider using async processing.

4. **Use pattern matching**: Subscribe to specific event patterns to reduce overhead:
   ```ruby
   # Subscribe only to workflow events
   ActiveSupport::Notifications.subscribe(/roast\.workflow\./) do |name, start, finish, id, payload|
     # Handle only workflow events
   end
   ```

5. **Consider performance impact**: While instrumentation is valuable, too many subscribers can impact performance. Be selective about what you instrument.

## Testing Your Instrumentation

You can test your instrumentation by creating a simple workflow and observing the events:

```yaml
# test_instrumentation.yml
name: instrumentation_test
steps:
  - test_step
```

Then run:
```bash
roast execute test_instrumentation.yml some_file.rb
```

Your instrumentation should capture the workflow start, step execution, and workflow completion events.

## Available Tools

Roast provides several built-in tools that you can use in your workflows:

### WriteFile Tool

Writes content to a file, creating the file if it doesn't exist or overwriting it if it does.

```ruby
# Example usage in a prompt
write_file(path: "output.txt", content: "This is the file content")
```

### UpdateFiles Tool

Applies a unified diff/patch to one or more files. Changes are applied atomically when possible.

```ruby
# Example usage in a prompt
update_files(diff: <<~DIFF, base_path: "/path/to/project", create_files: true)
  --- a/file1.txt
  +++ b/file1.txt
  @@ -1,3 +1,4 @@
   line1
  +new line
   line2
   line3
  
  --- a/file2.txt
  +++ b/file2.txt
  @@ -5,7 +5,7 @@
   line5
   line6
  -old line7
  +updated line7
   line8
DIFF
```

This tool is especially useful for making targeted changes to multiple files at once, without having to replace entire file contents.