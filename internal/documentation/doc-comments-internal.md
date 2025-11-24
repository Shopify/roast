# Developer-Facing Documentation Guidelines

This document provides guidelines for writing developer-facing documentation comments in Roast. Developer-facing documentation appears in internal implementation code that Roast core contributors work with directly.

## Where This Applies

Developer-facing documentation can be more concise since developers have the code right in front of them.

**Applies to:**

- Cog classes themselves (e.g., `Agent`, `Chat`, `Cmd`)
- All `Params` classes for system cogs (e.g., `SystemCog::Params`)
- Standard cog methods like `execute`, `initialize`
- Internal helper methods and utilities
- Private methods (if documented at all)

## Documentation Requirements

Developer-facing documentation should be concise and focused:

- Focus on usage, interface guarantees, and expectations
- Do **NOT** describe implementation details
- Do **NOT** include `#### See Also` sections (code is right there)
- Keep it concise - one-line summary is often sufficient
- Only add additional context when interface contracts aren't obvious from the method signature

## Basic Format

Documentation comments follow this minimal structure:

```ruby
# [One-line summary of what the method does]
#
#: (ParamType) -> ReturnType  # Type signatures are enforced by Sorbet/RuboCop
def method_name(param)
  # implementation
end
```

For methods where the interface contract is clear from the signature, a one-line description is sufficient:

```ruby
# Execute the agent with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

## Writing Clear Descriptions

### One-Line Descriptions

Start with a clear, action-oriented description in imperative mood. The first line should **not** end with a period:

```ruby
# Execute the chat completion with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

**Good patterns:**

- "Execute..."
- "Initialize..."
- "Get..."
- "Create..."

**Avoid:**

- Passive voice: "The input is executed..."
- Redundant phrases: "This method executes..."
- Implementation details: "Calls the provider's invoke method..."
- Ending with a period

### When to Add Additional Context

Only add additional lines when the interface contract isn't obvious from the method signature and one-line description:

```ruby
# Get the RubyLLM context configured for this chat cog
#
# Returns a cached context object that is lazily initialized on first access
# and reused for subsequent calls.
#
#: () -> RubyLLM::Context
def ruby_llm_context
  @ruby_llm_context ||= RubyLLM.context do |context|
    # configuration
  end
end
```

In this example, the additional context about caching and lazy initialization is valuable because it's not obvious from the signature.

## Class Documentation

Document cog classes with a brief description of their purpose:

```ruby
# Agent cog for executing AI agent workflows
#
# Enables interaction with AI agent providers to perform complex reasoning
# and tool-using tasks. Unlike the simpler chat cog, agents can use tools,
# maintain session state, and track detailed execution statistics.
class Agent < Cog
  # ...
end
```

**Key points:**

- Describe the cog's purpose concisely
- Mention key capabilities that distinguish it from other cogs
- Do NOT include `#### See Also` sections
- Do NOT describe implementation details

## Error Class Documentation

Document error classes with brief descriptions of when they're raised:

```ruby
# Parent class for all agent cog errors
class AgentCogError < Roast::Error; end

# Raised when an unknown or unsupported provider is specified
class UnknownProviderError < AgentCogError; end

# Raised when a required provider is not configured
class MissingProviderError < AgentCogError; end
```

**Key points:**

- One line is sufficient
- Describe when the error is raised
- No need for extensive context

## Attribute Documentation

Document public attributes with brief descriptions:

```ruby
# The configuration object for this agent cog instance
#
#: Agent::Config
attr_reader :config
```

**Key points:**

- One line is usually sufficient
- Do NOT include `#### See Also` sections
- Type signature provides most of the needed information

## Standard Method Patterns

### Execute Methods

All cog `execute` methods should have minimal documentation:

```ruby
# Execute the agent with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

**Do NOT document:**
- What happens internally (provider invocation, display logic, etc.)
- Configuration options (those are documented in Config class)
- Implementation details

### Initialize Methods

Rarely need documentation beyond type signature since constructor behavior is standard:

```ruby
#: (String response) -> void
def initialize(response)
  super()
  @response = response
end
```

Only add a comment if the initialization does something non-obvious.

## What Not to Document

Avoid documenting:

- **Implementation details** - How the method accomplishes its goal
- **Obvious information** - What's clear from the method name and signature
- **Private methods** - Generally don't need documentation comments
- **Internal mechanics** - Instance variable usage, caching strategies, etc.
- **Cross-references** - Code is right there, no need for `#### See Also`

**Bad example:**

```ruby
# Execute the agent by calling the provider's invoke method with the input,
# then checking the config to see if we should print the prompt, response,
# and stats to the console, and finally returning the output object
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

This is too detailed and describes implementation rather than interface.

**Good example:**

```ruby
# Execute the agent with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

## Markdown Formatting

Use minimal markdown formatting in developer-facing documentation:

### Inline Code

Use backticks for:

- Method names: `` `execute` ``
- Values: `` `true` ``, `` `:claude` ``
- Cog names: `` `call` ``, `` `map` ``, `` `agent` `` (they appear as methods from a user's perspective)
- Class names: Use **fully qualified names** (e.g., `` `Roast::DSL::Cogs::Agent::Input` ``)

**Important:** Always use fully qualified class/module names in documentation to avoid ambiguity.
Due to significant name overlap in the system (e.g., multiple `Input`, `Output`, `Config` classes),
shortened names can be confusing. Use the complete module path.

**Note:** "System" cogs (like `call`, `map`, `repeat`) are an internal implementation detail that inherit from `SystemCog` rather than `Cog`. This distinction is irrelevant in documentation - all cogs should be presented consistently regardless of their base class.

```ruby
# Get a RubyLLM context configured for this chat cog
#
#: () -> RubyLLM::Context
def ruby_llm_context
  # implementation
end
```

**Examples:**
- ✅ Good: `` `Roast::DSL::SystemCogs::Call::Output` ``
- ❌ Bad: `` `Call::Output` `` (ambiguous)

### Bold Emphasis

Use sparingly, only for critical negations if needed:

```ruby
# Execute the agent but do __not__ display progress to the console
#
#: (Input) -> Output
def execute_silently(input)
  # implementation
end
```

### No Subsections

Do **NOT** use subsections like `#### See Also` in developer-facing documentation. Developers can see related methods in the code.

## Review Checklist

Before finalizing developer-facing documentation, verify:

- [ ] One-line description is clear and action-oriented
- [ ] First line does not end with a period
- [ ] Focus is on interface contract (what it does), not implementation (how it does it)
- [ ] No `#### See Also` sections are included (code is right there)
- [ ] Documentation is concise - additional context only when interface isn't obvious
- [ ] No implementation details are exposed
- [ ] Error conditions are mentioned only if not obvious from signature
- [ ] Markdown formatting is correct

## Examples

### Minimal Documentation (Preferred)

```ruby
# Execute the chat completion with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

### With Necessary Context

```ruby
# Get the RubyLLM context configured for this chat cog
#
# Returns a cached context object that is lazily initialized on first access
# and reused for subsequent calls.
#
#: () -> RubyLLM::Context
def ruby_llm_context
  @ruby_llm_context ||= RubyLLM.context do |context|
    context.openai_api_key = config.valid_api_key!
    context.openai_api_base = config.valid_base_url
  end
end
```

### Class Documentation

```ruby
# Chat cog for executing simple LLM chat completions
#
# Provides a straightforward interface for single-turn interactions with
# language models without tool use or conversation state management.
class Chat < Cog
  # ...
end
```

### Error Class Documentation

```ruby
# Parent class for all agent cog errors
class AgentCogError < Roast::Error; end

# Raised when an unknown or unsupported provider is specified
class UnknownProviderError < AgentCogError; end
```
