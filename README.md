![roast-horiz-logo](https://github.com/user-attachments/assets/f9b1ace2-5478-4f4a-ac8e-5945ed75c5b4)

# Roast

### 🔥 _version 1.0 feature preview_ 🔥  
A Ruby-based domain-specific language for creating structured AI workflows. Build complex AI-powered automation with simple, declarative Ruby syntax.

> #### ⚠️ Deprecation announcement ⚠️
> The YAML-based workflow syntax of Roast `v0.x` will be removed in `v1.0`.
> All `v0.x` functionality is still supported during the feature preview.
> For the existing documentation for Roast `v0.x` , see [README_LEGACY.md](README_LEGACY.md)  

## Overview

Roast lets you orchestrate AI workflows by combining "cogs" - building blocks that interact with LLMs, run code, execute commands, and process data. Write workflows that:

- **Chain AI steps together** - Output from one cog flows seamlessly to the next
- **Run coding agents locally** - Full filesystem access with Claude Code or other providers
- **Process collections** - Map operations over arrays with serial or parallel execution
- **Control flow intelligently** - Conditional execution, iteration, and error handling
- **Reuse workflow components** - Create modular, parameterized scopes

## Quick Example

```ruby
# analyze_codebase.rb
execute do
  # Get recent changes
  cmd(:recent_changes) { "git diff --name-only HEAD~5..HEAD" }

  # AI agent analyzes the code
  agent(:review) do
    files = cmd!(:recent_changes).lines
    <<~PROMPT
      Review these recently changed files for potential issues:
      #{files.join("\n")}

      Focus on security, performance, and maintainability.
    PROMPT
  end

  # Summarize for stakeholders
  chat(:summary) do
    "Summarize this for non-technical stakeholders:\n\n#{agent!(:review).response}"
  end
end
```

Run with:
```bash
bin/roast execute analyze_codebase.rb
```

## Core Cogs

- **`chat`** - Send prompts to cloud-based LLMs (OpenAI, Anthropic, Gemini, etc.)
- **`agent`** - Run local coding agents with filesystem access (Claude Code CLI, etc.)
- **`ruby`** - Execute custom Ruby code within workflows
- **`cmd`** - Run shell commands and capture output
- **`map`** - Process collections in serial or parallel
- **`repeat`** - Iterate until conditions are met
- **`call`** - Invoke reusable workflow scopes

## Installation

```bash
gem install roast-ai
```

Or add to your Gemfile:
```ruby
gem 'roast-ai'
```

## Requirements

- Ruby 3.0+
- API keys for your AI provider (OpenAI/Anthropic)
- Claude Code CLI installed (for agent cog)

## Getting Started

The best way to learn Roast is through the interactive tutorial:

📚 **[Start the Tutorial](https://github.com/Shopify/roast/blob/main/tutorial/README.md)**

The tutorial covers:
1. Your first workflow
2. Chaining cogs together
3. Accepting targets and parameters
4. Configuration options
5. Control flow
6. Reusable scopes
7. Processing collections
8. Iterative workflows
9. Async execution

## Documentation

- [Tutorial](https://github.com/Shopify/roast/blob/main/tutorial/README.md) - Step-by-step guide with examples
- [Functional Tests](https://github.com/Shopify/roast/tree/main/dsl) - Toy workflows that demonstrate all functional patterns, use for end-to-end test
- [API Reference](https://github.com/Shopify/roast/tree/main/sorbet/rbi/shims/lib/roast/dsl) - Complete cog documentation

## Documentation & References

> ⚠️ Roast stills supports the legacy version `0.x`.
> Examples of workflows using the new version `1.0-preview` system 
> are namespaced within the `dsl` hierarchy.

* __v1.0 source code root__: https://github.com/Shopify/roast/tree/main/lib/roast/dsl

The public interfaces of the new Roast are extensively documented in
class and method comments on the relevant classes.

* __Tutorial and Examples__
    * [Tutorial -- Table of Contents](https://github.com/Shopify/roast/tree/main/tutorial) (contains step-by-step guides and runnable examples showing real-world usage)
    * [Additional Example Workflows](https://github.com/Shopify/roast/tree/main/dsl) (these comprise the Roast end-to-end test suite)
* __Configuation__
    * [General configuration block: `config-context.rbi`](https://github.com/Shopify/roast/blob/main/sorbet/rbi/shims/lib/roast/dsl/config_context.rbi)
    * [Global cog configuration: `cog/config.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cog/config.rb)
    * [Agent cog configuration: `agent/config.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/agent/config.rb)
    * [Chat cog configuration: `chat/config.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/chat/config.rb)
    * [Cmd cog configuration: `cmd/config.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/cmd.rb)
    * [Map cog configuration: `map.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/system_cogs/map.rb)
* __Execution__
    * [General Execution block: `execution-context.rbi`](https://github.com/Shopify/roast/blob/main/sorbet/rbi/shims/lib/roast/dsl/execution_context.rbi)
* __Input and Output__
    * [General cog input block: `cog-input-context.rbi`](https://github.com/Shopify/roast/blob/main/sorbet/rbi/shims/lib/roast/dsl/cog_input_context.rbi)
    * [Global cog output: `cog/output.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cog/output.rb)
    * [Agent cog input `agent/input.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/agent/input.rb)
    * [Agent cog output `agent/output.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/agent/output.rb)
    * [Call cog input: `call.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/system_cogs/call.rb)
    * [Chat cog input: `chat.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/chat/input.rb)
    * [Chat cog output: `chat.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/chat/output.rb)
    * [Cmd cog input: `cmd.rb:159`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/cmd.rb#L159) (scroll down)
    * [Cmd cog output: `cmd.rb:214`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/cmd.rb#L214) (scroll down)
    * [Map cog input: `map.rb:116`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/system_cogs/map.rb#L116) (scroll down)
    * [Repeat cog input: `repeat.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/system_cogs/repeat.rb)
    * [Ruby cog input: `ruby.rb`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/ruby.rb)
    * [Ruby cog output: `ruby.rb:63`](https://github.com/Shopify/roast/blob/main/lib/roast/dsl/cogs/ruby.rb#L63) (scroll down)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

[MIT License](LICENSE)
