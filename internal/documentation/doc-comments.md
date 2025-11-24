# Documentation Comment Guidelines

This document establishes standards for writing documentation comments in the Roast DSL codebase. Well-documented interfaces are critical for both internal development and community contributions.

## Purpose and Audience

Documentation comments should serve developers who will use these interfaces, not just those who will maintain them.
Write for:

- Roast core contributors
- Community contributors
- Users extending Roast with custom cogs

## Architectural Context

Before writing documentation, consult [architectural-notes.md](./architectural-notes.md) for key architectural decisions and distinctions that should guide how we talk about cogs and their functionality. This file captures important context such as:

- The distinction between `agent` and `chat` cogs
- Design decisions that affect how we describe cog capabilities
- Guidelines for avoiding misleading characterizations

Always ensure your documentation aligns with the architectural guidance in that file.

## Two Types of Documentation

Roast has two distinct types of documentation with different thoroughness requirements. Understanding which type you're writing is essential to creating appropriate documentation.

### User-Facing Documentation (External)

**For workflows users interact with directly.**

User-facing documentation appears in interfaces that Roast users write in their workflow files. These require the **most thorough documentation** and should **NOT assume knowledge** of how Roast works internally.

**Where user-facing documentation appears:**

- All `Config` classes for cogs (e.g., `Agent::Config`, `Chat::Config`, `Cmd::Config`)
- All `Input` classes for cogs (e.g., `Agent::Input`, `Chat::Input`)
- All `Output` classes for cogs (e.g., `Agent::Output`, `Chat::Output`)
- `.rbi` shims in `sorbet/rbi/shims/lib/roast/` - **These are critically important!**

#### Why .rbi Shims Are Critical

The `.rbi` shim files contain some of the most important user-facing documentation in Roast. These files define the methods that users call when writing workflows, and the documentation in these files is what users see in their IDE when they invoke these methods.

**Key .rbi shim files and their purposes:**

- **`execution_context.rbi`**: Documents methods users call when defining cogs in `execute` blocks (e.g., `agent!`, `chat!`, `cmd!`, `call!`, `map!`, `repeat!`)
- **`config_context.rbi`**: Documents methods users call when configuring cogs in `config` blocks (e.g., `agent { ... }`, `chat { ... }`, `cmd { ... }`)
  - **This is the primary way users discover what configuration options are available**
  - Must document ALL user-facing configuration methods on each cog's Config object (excluding internal methods like `valid_*`)
  - Configuration options should be grouped by purpose using `####` subsection headers (e.g., "Configure the LLM provider", "Configure the working directory")
- **`cog_input_context.rbi`**: Documents methods users call in cog input blocks to access outputs from other cogs (e.g., `from`, `collect`, `reduce`)

These files provide the primary interface between users and Roast. The documentation must be exceptional because it's what users see at the exact moment they need help.

**Requirements:**

- Be extremely thorough
- Include comprehensive `#### See Also` sections with cross-references
- Explain default behaviors and edge cases
- Document error conditions
- Provide context about what the method does and why you'd use it
- Don't assume the reader understands Roast internals

**📖 See [doc-comments-external.md](./doc-comments-external.md) for complete user-facing documentation guidelines.**

**Example:**

```ruby
# Configure the cog to use a specified provider when invoking an agent
#
# The provider is the source of the agent tool itself.
# If no provider is specified, Anthropic Claude Code (`:claude`) will be used as the default provider.
#
# A provider must be properly installed on your system in order for Roast to be able to use it.
#
# #### See Also
# - `use_default_provider!`
#
#: (Symbol) -> void
def provider(provider)
  @values[:provider] = provider
end
```

### Developer-Facing Documentation (Internal)

**For Roast core implementation code.**

Developer-facing documentation appears in internal implementation code that Roast core contributors work with directly. These can be **more concise** since developers have the code right in front of them.

**Where developer-facing documentation appears:**

- Cog classes themselves (e.g., `Agent`, `Chat`, `Cmd`)
- All `Params` classes for system cogs (e.g., `SystemCog::Params`)
- Standard cog methods like `execute`, `initialize`
- Internal helper methods and utilities
- Private methods (if documented at all)

**Requirements:**

- Focus on usage, interface guarantees, and expectations
- Do **NOT** describe implementation details
- Do **NOT** include `#### See Also` sections (code is right there)
- Keep it concise - one-line summary is often sufficient
- Only add additional context when interface contracts aren't obvious from the method signature

**📖 See [doc-comments-internal.md](./doc-comments-internal.md) for complete developer-facing documentation guidelines.**

**Example:**

```ruby
# Execute the agent with the given input and return the output
#
#: (Input) -> Output
def execute(input)
  # implementation
end
```

Notice: no `#### See Also`, no detailed explanation of what happens internally, just the interface contract.

## Quick Reference

### When to Use External Guidelines

Use [doc-comments-external.md](./doc-comments-external.md) when documenting:

- ✅ `Config` class methods (all configuration setters, getters, predicates)
- ✅ `Input` class methods and attributes
- ✅ `Output` class methods and attributes
- ✅ `.rbi` shim definitions (especially `execution_context.rbi`, `config_context.rbi`, `cog_input_context.rbi`)

### When to Use Internal Guidelines

Use [doc-comments-internal.md](./doc-comments-internal.md) when documenting:

- ✅ Cog class definitions (e.g., `class Agent < Cog`)
- ✅ `Params` class methods and attributes (e.g., `SystemCog::Params`)
- ✅ `execute` methods on cog classes
- ✅ `initialize` methods on cog classes
- ✅ Private helper methods
- ✅ Internal utilities and support classes

## General Principles

Regardless of which type of documentation you're writing, follow these universal principles:

### One-Line Descriptions

- Start with a clear, action-oriented description in imperative mood
- The first line should **NOT** end with a period
- Use active voice, not passive
- Be specific and precise

### Multi-Line Descriptions

- Separate paragraphs with blank comment lines
- All lines after the first line should be complete sentences ending with a period
- Add context and details after the one-line summary

### Markdown Formatting

- Use double underscores (`__word__`) for bold emphasis on critical negating words
- Use backticks (`` `code` ``) for method names, values, symbols, class names, and cog names
- **Cog names should always be stylized with backticks** (e.g., `` `call` ``, `` `map` ``, `` `agent` ``) since they appear as methods from a user's perspective
- **Always use fully qualified class/module names** (e.g., `Roast::DSL::SystemCogs::Call::Output`, not `Call::Output`) to avoid ambiguity
- Use `####` for subsection headers in user-facing documentation only
- Use `-` for bullet lists

**Note:** "System" cogs are an internal implementation detail. From the user's perspective, all cogs provided by core Roast should be presented the same way. Never distinguish between "system cogs" and "regular cogs" in user-facing documentation.

**Note:** `ExecutionManager` is an internal implementation detail. Never mention execution managers in user-facing documentation (Config, Input, Output classes). Focus on what the user can do with the output, not on the internal mechanisms.

### Type Signatures

- Always include inline RBS type signatures using `#:` comments
- Type signatures are enforced by Sorbet and RuboCop
- Place type signatures immediately before the method definition

### What Not to Document

- **Implementation details** - Focus on behavior, not how it's achieved
- **Obvious information** - Don't state what's clear from the method name
- **Internal mechanics** - How instance variables work, caching strategies, etc.

## Getting Started

1. **Identify which type of documentation you need:**
   - Are you documenting a Config/Input/Output class or .rbi shim? → Use [external guidelines](./doc-comments-external.md)
   - Are you documenting a Params class, cog class, or internal method? → Use [internal guidelines](./doc-comments-internal.md)

2. **Read the appropriate guide:**
   - [doc-comments-external.md](./doc-comments-external.md) - Comprehensive user-facing documentation
   - [doc-comments-internal.md](./doc-comments-internal.md) - Concise developer-facing documentation

3. **Follow the examples and patterns** in your chosen guide

4. **Review your documentation** using the checklist at the end of your guide

## Questions?

If you're unsure which type of documentation applies:

- **Ask yourself:** "Will a Roast user call this method directly in their workflow file or see this documentation in their IDE?"
  - If YES → Use external (user-facing) guidelines
  - If NO → Use internal (developer-facing) guidelines

- **.rbi shim files are always user-facing** - If you're documenting anything in `sorbet/rbi/shims/lib/roast/`, use external guidelines

- **Still unsure?** Default to external guidelines - it's better to be thorough than too brief.
