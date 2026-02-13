![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Chapter 10: Custom Cogs

🔥 _version 1.0 feature preview_ 🔥

## Overview

Roast's built-in cogs (`chat`, `agent`, `cmd`, `ruby`, `map`, `repeat`, `call`) cover many common use cases, but sometimes you need specialized functionality. Custom cogs let you:

- **Integrate external services** - API clients, databases, cloud services
- **Reuse complex logic** - Multi-step operations that you use across workflows
- **Add domain-specific operations** - Business logic specific to your organization
- **Create testable components** - Isolated units with clear inputs and outputs
- **Package and share functionality** - As gems or local files

This chapter teaches you how to create custom cogs that seamlessly integrate with Roast workflows.

## When to Create a Custom Cog

Create custom cogs when you need to:

✅ **Wrap an external API or service** that you call frequently
✅ **Encapsulate multi-step logic** that appears in multiple workflows
✅ **Add organization-specific operations** (e.g., deploy to your infrastructure)
✅ **Create reusable, testable components** with clear interfaces

❌ Don't create a custom cog for one-off operations - use the `ruby` cog instead
❌ Don't create a cog just to wrap a single method call - keep it simple

## Anatomy of a Cog

Every cog has three main components:

```ruby
class MyCog < Roast::Cog
  # 1. Config - Configuration options (optional)
  class Config < Roast::Cog::Config
    attr_accessor :timeout

    def initialize
      @timeout = 30
    end
  end

  # 2. Input - Defines what data the cog accepts
  class Input < Roast::Cog::Input
    attr_accessor :query

    def validate!
      raise "Query is required" if query.nil? || query.empty?
      true
    end
  end

  # 3. Output - Defines what data the cog returns (optional)
  class Output < Roast::Cog::Output
    attr_accessor :result, :count
  end

  # Execute method - The cog's main logic
  def execute(input)
    # Access config via @config
    # Process input
    # Return output (optional)

    Output.new.tap do |output|
      output.result = process(input.query)
      output.count = output.result.length
    end
  end
end
```

### Config (Optional)

The `Config` class defines configuration options that users can set in their workflows:

```ruby
class Config < Roast::Cog::Config
  attr_accessor :timeout, :retries

  def initialize
    @timeout = 30
    @retries = 3
  end
end
```

Users configure it in their workflow:

```ruby
config do
  my_cog do
    timeout 60
    retries 5
  end
end
```

### Input (Required)

The `Input` class defines what data the cog accepts and validation rules:

```ruby
class Input < Roast::Cog::Input
  attr_accessor :query, :limit

  def validate!
    raise "Query is required" if query.nil? || query.empty?
    raise "Limit must be positive" if limit && limit <= 0
    true
  end
end
```

### Output (Optional)

The `Output` class defines what data the cog returns:

```ruby
class Output < Roast::Cog::Output
  attr_accessor :results, :count, :success
end
```

If you don't define an Output class, the cog's return value becomes the output.

### Execute Method (Required)

The `execute` method contains the cog's main logic:

```ruby
def execute(input)
  # Access configuration
  timeout = @config.timeout

  # Process input
  results = fetch_data(input.query, timeout: timeout)

  # Return output
  Output.new.tap do |output|
    output.results = results
    output.count = results.length
    output.success = true
  end
end
```

## Simple Custom Cog Example

Here's the simplest possible custom cog:

```ruby
# cogs/simple.rb
class Simple < Roast::Cog
  class Input < Roast::Cog::Input
    def validate!
      true
    end
  end

  def execute(input)
    puts "I'm a cog!"
  end
end
```

See the complete example: [`examples/plugin-gem-example/lib/simple.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/simple.rb)

## Using Custom Cogs in Workflows

### From a Gem

If you've packaged your cog in a gem:

```ruby
# workflow.rb
use "simple", from: "my_gem"

execute do
  simple  # Invokes Simple cog
end
```

### From Local Files

For project-specific cogs:

```ruby
# workflow.rb
use "local"  # Loads from ./cogs/local.rb

execute do
  local  # Invokes Local cog
end
```

The `use` directive automatically loads `.rb` files from the `cogs/` directory relative to your workflow file.

### Loading Multiple Cogs

```ruby
# Load multiple cogs from a gem
use "simple", "other", from: "my_gem"

# Load namespaced cogs
use "MyCogNamespace::Other", from: "my_gem"

# Mix gem and local cogs
use "simple", "other", from: "my_gem"
use "local"

execute do
  simple
  other
  local
end
```

## Cog Naming Conventions

The cog method name is automatically derived from the class name using `underscore`:

- `Simple` → `simple`
- `DatabaseQuery` → `database_query`
- `MyCustomCog` → `my_custom_cog`
- `MyCogNamespace::Other` → `other` (namespace is stripped)

## File Structure for Local Cogs

Place local cogs in a `cogs/` directory relative to your workflow:

```
my_project/
├── workflow.rb
└── cogs/
    ├── local.rb          # Simple cog
    └── database_query.rb # More complex cog
```

Each file should define one cog class matching the filename.

## Complete Custom Cog Example

Let's build a more realistic example - a cog that fetches weather data:

```ruby
# cogs/weather.rb
require "net/http"
require "json"

class Weather < Roast::Cog
  class Config < Roast::Cog::Config
    attr_accessor :api_key, :timeout

    def initialize
      @timeout = 10
    end
  end

  class Input < Roast::Cog::Input
    attr_accessor :city

    def validate!
      raise "City is required" if city.nil? || city.empty?
      true
    end
  end

  class Output < Roast::Cog::Output
    attr_accessor :temperature, :conditions, :city
  end

  def execute(input)
    weather_data = fetch_weather(input.city)

    Output.new.tap do |output|
      output.city = input.city
      output.temperature = weather_data["temp"]
      output.conditions = weather_data["conditions"]
    end
  end

  private

  def fetch_weather(city)
    uri = URI("https://api.weather.example.com/v1/weather?city=#{city}&key=#{@config.api_key}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
end
```

Use it in a workflow:

```ruby
# workflow.rb
use "weather"

config do
  weather do
    api_key ENV["WEATHER_API_KEY"]
  end
end

execute do
  weather do
    city "San Francisco"
  end

  chat do
    <<~PROMPT
      The weather in #{weather!.city} is #{weather!.temperature}°F and #{weather!.conditions}.
      Should I bring an umbrella?
    PROMPT
  end
end
```

## Namespaced Cogs

For better organization, you can namespace your cogs:

```ruby
# lib/other.rb
module MyCogNamespace
  class Other < Roast::Cog
    class Input < Roast::Cog::Input
      def validate!
        true
      end
    end

    def execute(input)
      puts "I'm a namespaced cog!"
    end
  end
end
```

Use the full namespace when loading:

```ruby
use "MyCogNamespace::Other", from: "my_gem"

execute do
  other  # Method name is derived from class name (namespace stripped)
end
```

See the complete example: [`examples/plugin-gem-example/lib/other.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/other.rb)

## Working Examples

The Roast repository includes complete working examples of custom cogs:

### Simple Cog
- **Implementation:** [`examples/plugin-gem-example/lib/simple.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/simple.rb)
- Shows the minimal cog structure

### Namespaced Cog
- **Implementation:** [`examples/plugin-gem-example/lib/other.rb`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/other.rb)
- Shows how to organize cogs in namespaces

### Local Cog
- **Implementation:** [`examples/demo/cogs/local.rb`](https://github.com/Shopify/roast/tree/main/examples/demo/cogs/local.rb)
- Shows a project-specific cog loaded from local files

### Workflow Using Custom Cogs
- **Workflow:** [`examples/demo/simple_external_cog.rb`](https://github.com/Shopify/roast/tree/main/examples/demo/simple_external_cog.rb)
- Demonstrates loading and using multiple custom cogs (from gem and local)

Run the example:
```bash
cd examples/demo
bin/roast execute simple_external_cog.rb
```

## Creating a Gem with Custom Cogs

To share your custom cogs across projects, package them as a gem.

### Basic Gem Structure

```
my-roast-cogs/
├── lib/
│   ├── my_roast_cogs.rb       # Main gem file
│   ├── simple.rb               # Custom cog
│   ├── weather.rb              # Another cog
│   └── database_query.rb       # Yet another cog
├── my-roast-cogs.gemspec       # Gem specification
└── Gemfile
```

### Gem Specification

```ruby
# my-roast-cogs.gemspec
Gem::Specification.new do |spec|
  spec.name          = "my-roast-cogs"
  spec.version       = "1.0.0"
  spec.authors       = ["Your Name"]
  spec.summary       = "Custom Roast cogs for my organization"
  spec.description   = "A collection of reusable Roast cogs"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "roast-ai", "~> 1.0"
end
```

### Using Your Gem

```ruby
# Gemfile
gem "my-roast-cogs", path: "../my-roast-cogs"
# or for published gems:
# gem "my-roast-cogs", "~> 1.0"
```

```ruby
# workflow.rb
use "simple", "weather", "database_query", from: "my_roast_cogs"

execute do
  weather { city "Portland" }
  database_query { query "SELECT * FROM users LIMIT 10" }
  simple
end
```

### Complete Gem Example

See the complete example gem in the Roast repository:

- **Gem structure:** [`examples/plugin-gem-example/`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/)
- **Gemspec:** [`examples/plugin-gem-example/plugin-gem-example.gemspec`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/plugin-gem-example.gemspec)
- **Cog implementations:** [`examples/plugin-gem-example/lib/`](https://github.com/Shopify/roast/tree/main/examples/plugin-gem-example/lib/)

## Key Takeaways

- **Custom cogs extend Roast** with domain-specific operations and integrations
- **Three main components:** Config (optional), Input (required), Output (optional)
- **Execute method** contains the main logic
- **Use `use` directive** to load from gems or local files
- **Automatic naming** converts class names to method names (e.g., `Weather` → `weather`)
- **Local cogs** in `cogs/` directory for project-specific functionality
- **Package as gems** to share across projects and teams

## What's Next?

Continue to [Chapter 11: Custom Providers](../11_custom_providers/README.md) to learn how to create custom agent providers.
