![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Chapter 11: Custom Agent Providers

🔥 _version 1.0 feature preview_ 🔥

## Overview

The `agent` cog uses a provider system to execute agent tasks. By default, it uses the Claude Code CLI provider, but you can create custom providers to:

- **Integrate alternative agent backends** - Use different AI coding agents
- **Create mock agents for testing** - Simulate agent behavior without API calls
- **Wrap proprietary agent services** - Integrate your organization's internal tools
- **Add custom agent logic** - Pre-process prompts, post-process responses, etc.

This chapter teaches you how to create custom agent providers that seamlessly work with the `agent` cog.

## When to Create a Custom Provider

Create custom agent providers when you need to:

✅ **Integrate a different agent backend** (e.g., Cursor, Aider, custom agents)
✅ **Create mock agents for testing** workflows without API costs
✅ **Wrap proprietary agent services** specific to your organization
✅ **Add custom logic** around agent calls (logging, monitoring, retries)

## How Agent Providers Work

The built-in `agent` cog doesn't directly execute agent tasks. Instead, it:

1. Receives a prompt from the workflow
2. Passes the prompt to the configured **provider**
3. The provider executes the agent task (via API, CLI, etc.)
4. Returns an **Output** with the agent's response

```
Workflow → agent cog → Provider → Agent Backend
                          ↓
                       Output
```

The default provider uses the Claude Code CLI, but you can replace it with any custom implementation.

## Anatomy of a Provider

Every agent provider has two main components:

```ruby
class MyAgent < Roast::Cogs::Agent::Provider
  # 1. Output class - Defines what the provider returns
  class Output < Roast::Cogs::Agent::Output
    def stats
      # Return agent statistics (tokens used, etc.)
      Roast::Cogs::Agent::Stats.new(
        input_tokens: 100,
        output_tokens: 50
      )
    end

    def response
      # Return the agent's text response
      "I completed the task successfully"
    end

    def success
      # Return whether the agent task succeeded
      true
    end
  end

  # 2. invoke method - The provider's main logic
  def invoke(input)
    # input.valid_prompt! gives you the user's prompt

    # Call your agent backend (API, CLI, etc.)
    result = call_agent_backend(input.valid_prompt!)

    # Return an Output instance
    Output.new
  end
end
```

### Output Class (Required)

The `Output` class must inherit from `Roast::Cogs::Agent::Output` and implement three methods:

```ruby
class Output < Roast::Cogs::Agent::Output
  def stats
    # Return statistics about the agent execution
    Roast::Cogs::Agent::Stats.new(
      input_tokens: @input_tokens,
      output_tokens: @output_tokens
    )
  end

  def response
    # Return the agent's text response
    @response_text
  end

  def success
    # Return true if the agent task succeeded, false otherwise
    @success
  end
end
```

**Key methods:**

- **`stats`** - Returns a `Roast::Cogs::Agent::Stats` object with token counts and other metrics
- **`response`** - Returns the agent's text response as a string
- **`success`** - Returns a boolean indicating success or failure

### invoke Method (Required)

The `invoke` method is called when the agent cog executes:

```ruby
def invoke(input)
  # Get the user's prompt
  prompt = input.valid_prompt!

  # Call your agent backend
  # This could be an API call, CLI command, etc.
  result = call_my_agent_service(prompt)

  # Create and return an Output instance
  Output.new.tap do |output|
    output.response_text = result[:response]
    output.success = result[:success]
    output.input_tokens = result[:input_tokens]
    output.output_tokens = result[:output_tokens]
  end
end
```

## Simple Custom Provider Example

Here's the simplest possible custom agent provider:

```ruby
# lib/cool_agent.rb
class CoolAgent < Roast::Cogs::Agent::Provider
  class Output < Roast::Cogs::Agent::Output
    def stats
      Roast::Cogs::Agent::Stats.new
    end

    def response
      "I think lakes are cool"
    end

    def success
      true
    end
  end

  def invoke(input)
    # input.valid_prompt! gives you the user's prompt
    # For this simple example, we ignore it and return a canned response
    Output.new
  end
end
```

This provider always returns the same response, regardless of the prompt. It's useful for testing or demonstrations.

See the complete example: [`examples/plugin-gem-example/lib/cool_agent.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/cool_agent.rb)

## Using Custom Providers in Workflows

### From a Gem

If you've packaged your provider in a gem:

```ruby
# workflow.rb
use "cool_agent", from: "my_gem"

config do
  agent do
    provider :cool_agent
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
```

### From Local Files

For project-specific providers:

```ruby
# workflow.rb
use "cool_agent"  # Loads from ./cogs/cool_agent.rb

config do
  agent do
    provider :cool_agent
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
```

The `use` directive automatically loads `.rb` files from the `cogs/` directory relative to your workflow file.

## Provider Naming Conventions

The provider name is automatically derived from the class name using `underscore`:

- `CoolAgent` → `:cool_agent`
- `MyCustomProvider` → `:my_custom_provider`
- `AiderAgent` → `:aider_agent`

Use the symbol version when configuring the agent cog:

```ruby
config do
  agent do
    provider :cool_agent  # Symbol derived from class name
  end
end
```

## Complete Custom Provider Example

Let's build a more realistic example - a provider that calls a hypothetical agent API:

```ruby
# lib/api_agent.rb
require "net/http"
require "json"

class ApiAgent < Roast::Cogs::Agent::Provider
  class Output < Roast::Cogs::Agent::Output
    attr_accessor :response_text, :success_flag, :input_tokens, :output_tokens

    def stats
      Roast::Cogs::Agent::Stats.new(
        input_tokens: @input_tokens || 0,
        output_tokens: @output_tokens || 0
      )
    end

    def response
      @response_text
    end

    def success
      @success_flag
    end
  end

  def invoke(input)
    prompt = input.valid_prompt!

    # Call the agent API
    result = call_agent_api(prompt)

    # Create output
    Output.new.tap do |output|
      output.response_text = result["response"]
      output.success_flag = result["success"]
      output.input_tokens = result["usage"]["input_tokens"]
      output.output_tokens = result["usage"]["output_tokens"]
    end
  end

  private

  def call_agent_api(prompt)
    uri = URI("https://agent-api.example.com/v1/execute")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { prompt: prompt, api_key: ENV["AGENT_API_KEY"] }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
```

Use it in a workflow:

```ruby
# workflow.rb
use "api_agent"

config do
  agent do
    provider :api_agent
  end
end

execute do
  agent { "Analyze this codebase and suggest improvements" }

  chat do
    "Summarize these improvements for stakeholders:\n\n#{agent!.response}"
  end
end
```

## Mock Provider for Testing

Custom providers are useful for testing workflows without making real agent calls:

```ruby
# lib/mock_agent.rb
class MockAgent < Roast::Cogs::Agent::Provider
  class Output < Roast::Cogs::Agent::Output
    attr_accessor :prompt

    def stats
      Roast::Cogs::Agent::Stats.new(
        input_tokens: prompt.length / 4,  # Rough estimate
        output_tokens: 50
      )
    end

    def response
      # Return a mock response based on the prompt
      if prompt.include?("test")
        "All tests passed successfully!"
      elsif prompt.include?("analyze")
        "Analysis complete. Found 3 potential issues."
      else
        "Task completed successfully."
      end
    end

    def success
      true
    end
  end

  def invoke(input)
    Output.new.tap do |output|
      output.prompt = input.valid_prompt!
    end
  end
end
```

Use it for testing:

```ruby
# test_workflow.rb
use "mock_agent"

config do
  agent do
    provider :mock_agent
  end
end

execute do
  agent { "Run all tests in the test/ directory" }

  ruby do
    puts "Agent response: #{agent!.response}"
    # Output: "Agent response: All tests passed successfully!"
  end
end
```

## Working Examples

The Roast repository includes a complete working example of a custom agent provider:

### Simple Agent Provider
- **Implementation:** [`examples/plugin-gem-example/lib/cool_agent.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/cool_agent.rb)
- Shows the minimal provider structure

### Workflow Using Custom Provider
- **Workflow:** [`examples/demo/simple_external_agent.rb`](https://github.com/Shopify/roast/tree/main/examples/demo/simple_external_agent.rb)
- Demonstrates loading and using a custom agent provider

Run the example:
```bash
cd examples/demo
bin/roast execute simple_external_agent.rb
```

## Creating a Gem with Custom Providers

To share your custom providers across projects, package them as a gem.

### Basic Gem Structure

```
my-roast-agents/
├── lib/
│   ├── my_roast_agents.rb      # Main gem file
│   ├── cool_agent.rb           # Custom provider
│   ├── api_agent.rb            # Another provider
│   └── mock_agent.rb           # Mock provider for testing
├── my-roast-agents.gemspec     # Gem specification
└── Gemfile
```

### Gem Specification

```ruby
# my-roast-agents.gemspec
Gem::Specification.new do |spec|
  spec.name          = "my-roast-agents"
  spec.version       = "1.0.0"
  spec.authors       = ["Your Name"]
  spec.summary       = "Custom Roast agent providers"
  spec.description   = "Alternative agent backends for Roast workflows"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "roast-ai", "~> 1.0"
end
```

### Using Your Gem

```ruby
# Gemfile
gem "my-roast-agents", path: "../my-roast-agents"
# or for published gems:
# gem "my-roast-agents", "~> 1.0"
```

```ruby
# workflow.rb
use "api_agent", from: "my_roast_agents"

config do
  agent do
    provider :api_agent
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
```

### Combining Providers and Cogs in One Gem

You can include both custom cogs and custom providers in the same gem:

```
my-roast-extensions/
├── lib/
│   ├── my_roast_extensions.rb
│   ├── cool_agent.rb          # Agent provider
│   ├── api_agent.rb           # Another provider
│   ├── weather.rb             # Custom cog
│   └── database_query.rb      # Another custom cog
├── my-roast-extensions.gemspec
└── Gemfile
```

See the complete example: [`examples/plugin-gem-example/`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/)

## Configuring Providers Per Agent Cog

You can use different providers for different agent cogs in the same workflow:

```ruby
use "cool_agent", from: "my_gem"
use "api_agent", from: "my_gem"

config do
  # Default provider for all agent cogs
  agent do
    provider :cool_agent
  end

  # Override for specific agent cogs
  agent(/analysis/) do
    provider :api_agent
  end
end

execute do
  agent(:review) { "Review this code" }       # Uses :cool_agent
  agent(:analysis) { "Deep analysis needed" } # Uses :api_agent
end
```

## Key Takeaways

- **Custom providers** integrate alternative agent backends with the `agent` cog
- **Two main components:** Output class (required) and invoke method (required)
- **Output class** must implement `stats`, `response`, and `success` methods
- **invoke method** receives the prompt and returns an Output instance
- **Use `use` directive** to load providers from gems or local files
- **Automatic naming** converts class names to provider symbols (e.g., `CoolAgent` → `:cool_agent`)
- **Mock providers** are useful for testing workflows without API calls
- **Package as gems** to share providers across projects and teams

## What's Next?

You've completed the Roast tutorial! Here are some next steps:

- Explore the [examples directory](https://github.com/Shopify/roast/tree/main/examples) for more real-world patterns
- Check out the [source code documentation](https://github.com/Shopify/roast/tree/main/lib/roast/dsl) for advanced features
- Build your own custom extensions and share them with the community

Happy building! 🔥
