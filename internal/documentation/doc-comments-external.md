# User-Facing Documentation Guidelines

This document provides guidelines for writing user-facing documentation comments in Roast. User-facing documentation appears in interfaces that Roast users interact with directly in their workflows.

## Where This Applies

User-facing documentation must be extremely thorough and should **NOT assume knowledge** of how Roast works internally.

**Required locations:**

- All `Config` classes for cogs (e.g., `Agent::Config`, `Chat::Config`, `Cmd::Config`)
- All `Input` classes for cogs (e.g., `Agent::Input`, `Chat::Input`)
- All `Output` classes for cogs (e.g., `Agent::Output`, `Chat::Output`)
- `.rbi` shims in `sorbet/rbi/shims/lib/roast/` - **These are critically important!**

## Architectural Context

Before writing user-facing documentation, consult [architectural-notes.md](./architectural-notes.md) for key architectural decisions and distinctions. This is especially important when documenting cog capabilities and distinctions. For example:

- The `agent` vs `chat` cog distinction (local system access vs pure LLM interaction)
- Avoiding misleading characterizations (e.g., don't call `chat` "simple" - it's capable of complex reasoning)
- Understanding the true limitations and capabilities of each cog

Always ensure your documentation accurately reflects the architectural design and doesn't inadvertently mislead users about what each cog can or cannot do.

### Why .rbi Shims Are Critical

The `.rbi` shim files contain some of the most important user-facing documentation in Roast. These files define the methods that users call when writing workflows, and the documentation in these files is what users see in their IDE when they invoke these methods.

**Key .rbi shim files and their purposes:**

- **`execution_context.rbi`**: Documents methods users call when defining cogs in `execute` blocks of their workflows
  - Methods like `agent!`, `chat!`, `cmd!`, `call!`, `map!`, `repeat!`
  - These are the primary ways users invoke cogs in their workflow definitions

- **`config_context.rbi`**: Documents methods users call when configuring cogs in `config` blocks of their workflows
  - Methods like `agent { ... }`, `chat { ... }`, `cmd { ... }`
  - These are how users apply configuration to cogs before execution

- **`cog_input_context.rbi`**: Documents methods users call in cog input blocks to access outputs from other cogs
  - Methods like `from`, `collect`, `reduce`
  - These are how users access and transform cog outputs within their workflow

These files provide the primary interface between users and Roast. The documentation must be exceptional because it's what users see at the exact moment they need help. When a user types `agent!` in their workflow, the documentation from `execution_context.rbi` is what appears in their IDE to guide them.

## Documentation Requirements

User-facing documentation should be comprehensive and include:

- Be extremely thorough
- Include comprehensive `#### See Also` sections with cross-references
- Explain default behaviors and edge cases
- Document error conditions
- Provide context about what the method does and why you'd use it
- Don't assume the reader understands Roast internals

## Basic Format

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

**When not to bold:**

Do not bold negating words when:
- The negation is obvious from context
- Missing the negating word wouldn't cause categorical misunderstanding
- The negative meaning is already clear from surrounding text

### Inline Code

Use backticks for:

- Method names: `` `provider` ``
- Values: `` `true` ``, `` `:claude` ``
- Symbols: `` `:name` ``
- Cog names: `` `call` ``, `` `map` ``, `` `agent` `` (they appear as methods from a user's perspective)
- Class names: Use **fully qualified names** (e.g., `` `Roast::DSL::Cog::Config::InvalidConfigError` ``)

**Important:** Always use fully qualified class/module names in documentation to avoid ambiguity.
Due to significant name overlap in the system (e.g., multiple `Input`, `Output`, `Config` classes),
shortened names can be confusing. Use the complete module path.

**Note:** "System" cogs are an internal implementation detail. From the user's perspective, all cogs provided by core Roast should be presented the same way. Never distinguish between "system cogs" and "regular cogs" in user-facing documentation.

**Note:** `ExecutionManager` is an internal implementation detail. Never mention execution managers in user-facing documentation. Focus on what the user can do with the output, not on the internal mechanisms used to produce it.

```ruby
# Configure the cog to use the default provider when invoking an agent
#
# The default provider used by Roast is Anthropic Claude Code (`:claude`).
#: () -> void
def use_default_provider!
  @values[:provider] = nil
end
```

**Examples:**
- ✅ Good: `` `Roast::DSL::SystemCogs::Call::Output` ``
- ✅ Good: `` `Roast::DSL::Cogs::Agent::Config` ``
- ❌ Bad: `` `Call::Output` `` (ambiguous)
- ❌ Bad: `` `Agent::Config` `` (which Agent?)

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

Always use `#### See Also` to list related user-facing methods and attributes in user-facing documentation.

**Critical Rule:** Only reference methods and attributes that users would actually call or access in their workflows, using user-facing syntax. Do __not__ reference class names or internal implementation details.

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
- Methods from included modules (e.g., `text`, `lines`, `json`, `json!`)
- Other user-facing methods and attributes that users would call in their workflows

**Do NOT include in See Also:**

- `valid_*` validation methods when documenting user-facing Config setter methods - these are internal implementation details
- Class names (e.g., `Roast::DSL::Cogs::Agent::Config`) - these are not user-facing references
- Internal implementation details or mechanisms
- Anything users wouldn't directly reference in their workflow code

**Formatting examples:**
- ✅ User-facing method: `` - `model` ``
- ✅ Attribute from same class: `` - `response` ``
- ✅ Method from included module: `` - `text` ``
- ❌ Class name: `` - `Roast::DSL::Cogs::Agent::Input` ``
- ❌ Internal method: `` - `valid_model!` ``

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

## ConfigContext Method Documentation (.rbi shims)

Methods in `config_context.rbi` expose cog configuration interfaces and are the **primary way users discover what configuration options are available**. These require exceptionally thorough documentation.

### Critical Requirements

**Document ALL user-facing configuration methods** - The documentation must list every configuration method that users can call on the cog's `Config` object. This is their primary discovery mechanism.

**Exclude internal methods** - Do NOT document internal implementation methods like `valid_*` validation methods.

**Group by purpose** - Organize configuration options by their purpose using `####` subsection headers. This helps users understand how options relate to each other.

### Structure

```ruby
# Configure the `agent` cog
#
# [Brief description of what this cog does - reference architectural-notes.md]
#
# ### Usage
# - `agent { &blk }` - Apply configuration to all instances of the `agent` cog
# - `agent(:name) { &blk }` - Apply configuration to the `agent` cog instance named `:name`
# - `agent(/regexp/) { &blk }` - Apply configuration to any `agent` cog whose name matches `/regexp/`
#
# ### Available Options
#
# Apply configuration within the block passed to `agent`:
#
# #### Configure the LLM provider
# - `provider(symbol)` - Set the agent provider (e.g., `:claude`)
# - `use_default_provider!` - Use the default provider (`:claude`)
#
# #### Configure the base command used to run the coding agent
# - `command(string_or_array)` - Set the base command for invoking the agent
# - `use_default_command!` - Use the provider's default command
#
# #### Configure the LLM model the agent should use
# - `model(string)` - Set the model to use
# - `use_default_model!` - Use the provider's default model
#
# #### Configure the working directory in which the coding agent process should run
# - `working_directory(path)` - Set the working directory for agent execution
# - `use_current_working_directory!` - Use the current working directory
#
# #### Configure whether the coding agent should be constrained by project- and user-level permissions specs
# - `apply_permissions!` - Apply permissions when running the agent
# - `skip_permissions!` (alias `no_apply_permissions!`) - Skip permissions (default)
#
#: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Agent::Config] -> void} -> void
def agent(name = nil, &block); end
```

### Key Guidelines

**Required sections:**

1. **Brief description** - One or two sentences describing the cog (consult `architectural-notes.md` for accurate characterizations)
2. **Usage** - Show all three calling patterns (all, named, regex)
3. **Available Options** - List ALL user-facing config methods, grouped by purpose

**Grouping configuration options:**

- Use `####` (four hashes) for purpose-based groupings
- Create clear, descriptive group headers (e.g., "Configure the LLM provider", "Configure the working directory")
- Within each group, list related methods together
- Each method should have a brief one-line description
- Note aliases inline using `(alias method_name)`

**What to include:**

- ✅ ALL setter methods that accept parameters (e.g., `provider(symbol)`, `model(string)`)
- ✅ ALL no-argument state-setting methods (e.g., `apply_permissions!`, `use_default_provider!`)
- ✅ Note default values where applicable (e.g., "Skip permissions (default)")

**What to exclude:**

- ❌ Validation methods (e.g., `valid_provider!`, `valid_model!`) - these are internal
- ❌ Predicate methods (e.g., `apply_permissions?`) - these are internal
- ❌ Any other internal implementation methods

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

Before finalizing user-facing documentation, verify:

- [ ] One-line description is clear and action-oriented
- [ ] First line does not end with a period
- [ ] All subsequent lines are complete sentences with proper punctuation
- [ ] Default behavior is documented (if applicable)
- [ ] Related user-facing methods/attributes are cross-referenced in `#### See Also` sections using user-facing syntax only
- [ ] `#### See Also` does NOT include class names, `valid_*` methods, or other internal implementation details
- [ ] Aliases are documented in an `#### Alias Methods` subsection (if applicable)
- [ ] The method itself is listed first in its own alias list, followed by aliases in alphabetical order
- [ ] Nil/false/true semantics are explained when not obvious
- [ ] Error conditions are mentioned and explained
- [ ] Critical negating words are bolded where missing them would cause misunderstanding
- [ ] Markdown formatting is correct
- [ ] No implementation details are exposed
- [ ] Context is provided about why you'd use this method
- [ ] No assumptions are made about the reader's knowledge of Roast internals
