# Documentation Comment Guidelines

This document establishes standards for writing documentation comments in the Roast DSL codebase. Well-documented
interfaces are critical for both internal development and community contributions.

## General Principles

### Purpose and Audience

Documentation comments should serve developers who will use these interfaces, not just those who will maintain them.
Write for:

- Roast core contributors
- Community contributors
- Users extending Roast with custom cogs

### Core Requirements

Every public method must have:

1. **A clear description** of what it does
2. **Default behavior** documented when applicable
3. **Related methods** cross-referenced when relevant

## Documentation Structure

### Basic Format

Documentation comments follow this structure:

```ruby
# [One-line summary of what the method does]
#
# [Optional: Additional details, context, or explanation]
#
# [Optional: Subsections for cross-references, notes, etc.]
#
#: (ParamType) -> ReturnType  # Type signatures are enforced by Sorbet/RuboCop
def method_name(param)
  # implementation
end
```

## Writing Clear Descriptions

### One-Line Descriptions

Start with a clear, action-oriented description in imperative mood. The first line should **not** end with a period:

```ruby
# Configure the cog to write STDOUT to the console
#: () -> void
def print_stdout!
  @values[:print_stdout] = true
end
```

**Good patterns:**

- "Configure the cog to..."
- "Get the validated..."
- "Check if the cog is configured to..."

**Avoid:**

- Passive voice: "The cog is configured to..."
- Redundant phrases: "This method configures..."
- Vague descriptions: "Sets a value"
- Ending with a period

### Multi-Line Descriptions

When more context is needed, separate paragraphs with blank comment lines. All lines after the first line should be complete sentences ending with a period or other appropriate punctuation:

```ruby
# Get the validated provider name that the cog is configured to use when invoking an agent
#
# Note: this method will return the name of a valid provider or raise an `InvalidConfigError`.
# It will not, however, validate that the agent is properly installed on your system.
# If the agent is not properly installed, you will likely experience a failure when Roast attempts to
# run your workflow.
#
#: () -> Symbol
def valid_provider!
  # implementation
end
```

## Markdown Formatting

### Emphasis

Use double underscores for bold emphasis to highlight critical negating words in key sentences:

```ruby
# Configure the cog __not__ to write STDOUT to the console
#: () -> void
def no_print_stdout!
  @values[:print_stdout] = false
end
```

**When to bold negating words:**

Bold negating words (like "not", "no", "never", "without") when:
- The word is critical to understanding what the method does
- A reader who misses the word would get a categorically incorrect understanding
- The negation is the key distinguishing feature of the method or statement

This is most commonly needed in the first line of documentation, but can apply anywhere the negation is critical.

**When not to bold:**

Do not bold negating words when:
- The negation is obvious from context
- Missing the negating word wouldn't cause categorical misunderstanding
- The negative meaning is already clear from surrounding text

**Example of appropriate bolding:**

```ruby
# Configure the cog __not__ to apply permissions when running the agent
#
# This method disables permission checking.
# Note that running without permissions may limit what the agent can do.
#
#: () -> void
def no_apply_permissions!
  @values[:apply_permissions] = false
end
```

In this example, "__not__" is bolded in the first line because it's critical to understanding, but "without" in the fourth line is not bolded because it's supplementary information and the negative meaning is already clear from "disables".

### Inline Code

Use backticks for:

- Method names: `` `provider` ``
- Values: `` `true` ``, `` `:claude` ``
- Symbols: `` `:name` ``
- Class names: `` `InvalidConfigError` ``

```ruby
# Configure the cog to use the default provider when invoking an agent
#
# The default provider used by Roast is Anthropic Claude Code (`:claude`).
#: () -> void
def use_default_provider!
  @values[:provider] = nil
end
```

### Subsections

Use `####` for subsection headers (four hashes):

```ruby
# Configure the cog to apply permissions when running the agent
#
# The cog's default behaviour is to run with __no__ permissions.
#
# #### Alias Methods
# - `apply_permissions!`
# - `no_skip_permissions!`
#
# #### Inverse Methods
# - `skip_permissions!`
# - `no_apply_permissions!`
#
#: () -> void
def apply_permissions!
  @values[:apply_permissions] = true
end
```

### Lists

Use `-` for bullet lists:

```ruby
# Configure the cog to use a specified provider when invoking an agent
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

## Cross-References and Related Methods

### See Also Sections

Use `#### See Also` to list related methods:

```ruby
# Configure the cog to use the provider's default model when invoking the agent
#
# Note: the default model will be different for different providers.
#
# #### See Also
# - `model`
#
#: () -> void
def use_default_model!
  @values[:model] = nil
end
```

**When to include See Also:**

- Complementary methods (setter/getter pairs)
- Alternative approaches to the same goal
- Related predicate methods (e.g., `show_prompt?`)

**Do NOT include in See Also for Config class methods:**

- `valid_*` validation methods - These are internal implementation details and should not be cross-referenced from user-facing configuration methods

### Alias and Inverse Method Documentation

For methods with aliases or inverse methods, document them in dedicated subsections using `#### Alias Methods` and `#### Inverse Methods`.

**Critical: List the method itself in its alias list**

Because Ruby aliases share the same documentation, when a user looks up an alias method, they see the original method's doc comment. Therefore, the `#### Alias Methods` list must include the method itself as the first entry, followed by all its aliases in alphabetical order.

```ruby
# Configure the cog to run the agent with __no__ permissions applied
#
# The cog's default behaviour is to run with __no__ permissions.
#
# #### Alias Methods
# - `no_apply_permissions!`
# - `skip_permissions!`
#
# #### Inverse Methods
# - `apply_permissions!`
# - `no_skip_permissions!`
#
#: () -> void
def no_apply_permissions!
  @values[:apply_permissions] = false
end

alias_method(:skip_permissions!, :no_apply_permissions!)
```

When someone looks up `skip_permissions!`, they will see this same documentation, which now correctly shows both `no_apply_permissions!` (the primary method) and `skip_permissions!` (the alias they're viewing).

**Key points:**

- Always use subsections for aliases (never inline documentation)
- Use `#### Alias Methods` for the subsection header
- **Always include the method itself as the first entry in the alias list**
- List remaining aliases in alphabetical order after the primary method
- List inverse methods in a separate `#### Inverse Methods` subsection

## Documenting Defaults and Behavior

### Default Values

Always document default behavior:

```ruby
# Configure the cog to strip surrounding whitespace from the values in its output object
#
# Default: `true`
#
#: () -> void
def clean_output!
  @values[:raw_output] = false
end
```

### Nil Handling

Explain what `nil` values mean when used as parameters or configuration states:

```ruby
# Configure the cog to use a specific model when invoking the agent
#
# Pass `nil` to use the provider's default model configuration.
#
#: (String?) -> void
def model(model)
  @values[:model] = model
end
```

### Error Conditions

Document when methods raise errors:

```ruby
# Get the validated provider name that the cog is configured to use when invoking an agent
#
# Note: this method will return the name of a valid provider or raise an `InvalidConfigError`.
# It will not, however, validate that the agent is properly installed on your system.
#
#: () -> Symbol
def valid_provider!
  # implementation
end
```

## Config Method Documentation

Config methods have specific patterns that should be followed consistently.

### Bang Method Convention

The bang (`!`) suffix is used in two distinct contexts:

1. **No-argument state setters** - Methods that set a configuration value to a specific state without taking arguments (e.g., `print_stdout!`, `no_display!`)
2. **Validation getters** - Methods that retrieve and validate configuration values and may raise errors (e.g., `valid_provider!`, `valid_working_directory_path!`)

Do **not** use bang for:
- Setter methods that accept a value parameter (e.g., `provider(value)`, `model(value)`)
- Simple predicate methods that check state (e.g., `print_stdout?`, `apply_permissions?`)

### Configuration Setters

Configuration setter methods come in two forms:

**Bang methods (no arguments)** - Use `method!` for no-argument methods that set a configuration value to a specific state:

```ruby
# Configure the cog to write STDOUT to the console
#
# Disabled by default
#
#: () -> void
def print_stdout!
  @values[:print_stdout] = true
end
```

**Value setters (with arguments)** - Use `method` without bang for methods that accept a value:

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

**Key points:**

- Use bang (`!`) only for no-argument state-setting methods
- Do not use bang for methods that accept a value parameter
- Describe what aspect of the cog is being configured
- Explain the purpose and context
- Document any requirements or prerequisites
- Cross-reference related methods

### Validation Getters

Validation getter methods use the `valid_*!` pattern and return a validated/coerced value or raise an error if validation fails. Currently primarily used for not-nil assertions, but will expand to other validations.

**Important:** These methods are internal implementation details. Configuration setter methods should __not__ cross-reference validation methods in their documentation. However, validation methods may cross-reference their corresponding setter methods.

```ruby
# Get the validated, configured value for the working directory path in which the cog should run the agent
#
# This method will raise an `InvalidConfigError` if the path does not exist or is not a directory.
#
# #### See Also
# - `working_directory`
# - `use_current_working_directory!`
#
#: () -> String
def valid_working_directory_path!
  # implementation with validation and error raising
end
```

**Key points:**

- Use the `valid_*!` naming pattern with bang suffix
- Return the validated/coerced value on success
- Raise an error if validation fails
- Always document what errors can be raised and under what conditions
- Start descriptions with "Get the validated..."
- These methods may cross-reference their related setter methods
- Configuration setter methods should __not__ reference validation methods

### Boolean Predicates

Predicate methods (those ending in `?`) check configuration state:

```ruby
# Check if the cog is configured to apply permissions when running the agent
#
# #### See Also
# - `apply_permissions!`
# - `no_apply_permissions!`
# - `skip_permissions!`
# - `no_skip_permissions!`
#
#: () -> bool
def apply_permissions?
  !!@values[:apply_permissions]
end
```

**Key points:**

- Start with "Check if..."
- Reference all related configuration methods
- Document what `true` and `false` mean if not obvious

### Path and Directory Configuration

Methods dealing with paths require extra documentation:

```ruby
# Configure the cog to run the agent in the specified working directory
#
# The directory given can be relative or absolute.
# If relative, it will be understood in relation to the directory from which Roast is invoked.
#
# #### See Also
# - `use_current_working_directory!`
#
#: (String) -> void
def working_directory(directory)
  @values[:working_directory] = directory
end
```

**Key points:**

- Explain relative vs absolute path handling
- Document the base directory for relative paths
- Cross-reference complementary configuration methods

## ConfigContext Method Documentation

Methods in `ConfigContext` that expose cog configuration interfaces require comprehensive documentation since they're
the primary user-facing API:

```ruby
# Configure the `cmd` cog
#
# ### Usage
# - `cmd { &blk }` - Apply configuration to all instances of the `cmd` cog.
# - `cmd(:name) { &blk }` - Apply configuration to the instance of the `cmd` cog named `:name`
# - `cmd(/regexp/) { &blk }` - Apply configuration to any instance of the `cmd` cog whose name matches `/regexp/`
#
# ---
#
# ### Available Options
#
# Apply configuration within the block passed to `cmd`.
#
# These methods are available to apply configuration options to the `cmd` cog:
# - `print_all!`  Configure the cog to write both STDOUT and STDERR to the console
#   - alias `display!`
# - `print_none!` -  Configure the cog to write __no output__ to the console, neither STDOUT nor STDERR
#   - alias `no_display!`
# - `print_stdout!` - Configure the cog to write STDOUT to the console
# - `no_print_stdout!` - Configure the cog __not__ to write STDOUT to the console
#
#: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Cmd::Config] -> void} -> void
def cmd(name_or_pattern = nil, &block)
  ;
end
```

**Required sections:**

1. **Usage** - Show all the ways the method can be called
2. **Available Options** - List all configuration methods available in the block
3. **Horizontal rule** (`---`) separating major sections
4. Use `###` (three hashes) for these major sections

## Common Patterns and Examples

### Setter/Getter Pairs

```ruby
# Configure the cog to use a specific model when invoking the agent
#
#: (String) -> void
def model(model)
  @values[:model] = model
end

# Configure the cog to use the provider's default model when invoking the agent
#
# Note: the default model will be different for different providers.
#
# #### See Also
# - `model`
#
#: () -> void
def use_default_model!
  @values[:model] = nil
end

# Get the validated, configured model that the cog will use when running the agent
#
# This method will raise an `InvalidConfigError` if no valid model is configured.
#
# #### See Also
# - `model`
# - `use_default_model!`
#
#: () -> String
def valid_model!
  @values[:model].presence || raise(InvalidConfigError, "No valid model configured")
end
```

### Boolean Toggle Pairs

```ruby
# Configure the cog to write STDOUT to the console
#
# Disabled by default.
#
#: () -> void
def print_stdout!
  @values[:print_stdout] = true
end

# Configure the cog __not__ to write STDOUT to the console
#
#: () -> void
def no_print_stdout!
  @values[:print_stdout] = false
end

# Check if the cog is configured to write STDOUT to the console
#
#: () -> bool
def print_stdout?
  !!@values[:print_stdout]
end
```

## What Not to Document

Avoid documenting:

- **Implementation details** - Focus on behavior, not how it's achieved
- **Obvious information** - Don't state what's clear from the method name
- **Private methods** - Generally don't need documentation comments
- **Internal mechanics** - How `@values` hash works, etc.

**Bad example:**

```ruby
# Sets the print_stdout value in the @values hash to true
#: () -> void
def print_stdout!
  @values[:print_stdout] = true # Sets the value
end
```

**Good example:**

```ruby
# Configure the cog to write STDOUT to the console
#
# Disabled by default
#
#: () -> void
def print_stdout!
  @values[:print_stdout] = true
end
```

## Review Checklist

Before finalizing documentation for a public method, verify:

- [ ] One-line description is clear and action-oriented
- [ ] First line does not end with a period
- [ ] All subsequent lines are complete sentences with proper punctuation
- [ ] Default behavior is documented (if applicable)
- [ ] Related methods are cross-referenced (but Config setters do NOT reference `valid_*` methods)
- [ ] Aliases are documented in an `#### Alias Methods` subsection (if applicable)
- [ ] The method itself is listed first in its own alias list, followed by aliases in alphabetical order
- [ ] Nil/false/true semantics are explained when not obvious
- [ ] Error conditions are mentioned
- [ ] Critical negating words are bolded where missing them would cause misunderstanding
- [ ] Markdown formatting is correct
- [ ] No implementation details are exposed
- [ ] Examples are provided for complex cases
