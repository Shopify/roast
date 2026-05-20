# Architectural Notes

This document captures architectural decisions and key distinctions that should guide how we talk about cogs and their functionality in documentation comments.

## Execution Scope Invocation Pattern

The `call`, `map`, and `repeat` cogs all share a common architectural pattern: they invoke named execution scopes (defined with `execute(:name)`). Understanding this pattern is essential for correctly documenting how users access outputs from these cogs.

### The Three Scope Invocation Cogs

#### `call` - Single Scope Invocation

The `call` cog invokes an execution scope **once** with a provided value:

- Invokes a named scope with a single input value
- Returns output from that single invocation
- Use case: Reusable workflow segments that need to run once

#### `map` - Multiple Scope Invocations (Collection)

The `map` cog invokes an execution scope **multiple times**, once for each item in a collection:

- Invokes a named scope for each item in an iterable
- Each invocation receives one item as its value
- Returns outputs from all invocations
- Use case: Processing collections where each item gets the same treatment

#### `repeat` - Multiple Scope Invocations (Loop)

The `repeat` cog invokes an execution scope **multiple times** in a loop until `break!` is called:

- Invokes a named scope repeatedly with evolving input
- Each iteration's output becomes the next iteration's input
- Returns outputs from all iterations
- Use case: Iterative refinement or loops with dynamic exit conditions

### Output Access Methods

The output access methods (`from`, `collect`, `reduce`) are designed around this scope invocation pattern:

#### `from` - Access a Single Scope Invocation

The `from` method retrieves output from a **single** execution scope invocation:

- Works with `call` cogs (access the one invocation)
- Works with `map` or `repeat` cogs via `.iteration(n)` (access a specific iteration's invocation)
- Returns the final output from that scope's `outputs!` or `outputs` block
- With a block, executes in the context of that scope, allowing access to intermediate cog outputs

#### `collect` - Access All Scope Invocations (as Array)

The `collect` method retrieves outputs from **all** execution scope invocations:

- Works with `map` or `repeat` cogs (via `.results` for `repeat`)
- Returns an array of final outputs from all iterations
- With a block, executes in each scope's context, allowing access to intermediate cog outputs
- Iterations that didn't run (due to `break!`) are represented as `nil`

#### `reduce` - Access All Scope Invocations (as Single Value)

The `reduce` method combines outputs from **all** execution scope invocations into a single value:

- Works with `map` or `repeat` cogs (via `.results` for `repeat`)
- Processes each iteration sequentially with an accumulator
- With a block, executes in each scope's context, allowing access to intermediate cog outputs
- Skips iterations that didn't run (due to `break!`)

### Documentation Guidelines

When documenting these methods:

- **Do** emphasize that `call`, `map`, and `repeat` all invoke execution scopes
- **Do** explain that `from` is for accessing a single scope invocation
- **Do** explain that `collect` and `reduce` are for accessing all scope invocations from `map` or `repeat`
- **Don't** characterize `from` as only for `call` cogs - it works with any single scope invocation
- **Don't** characterize `collect`/`reduce` as only for `map` - they work with both `map` and `repeat` (via `.results`)
- **Do** clarify that blocks passed to these methods execute in the context of the invoked scope, not the current scope

## Agent Cog vs Chat Cog

The `agent` cog and `chat` cog are both LLM-powered cogs, but they serve different purposes based on their execution environment and capabilities.

### Agent Cog

The `agent` cog runs a coding agent on the local machine with access to local resources:

- **Local filesystem access**: Can read and write files on the local machine
- **Local tool execution**: Can run tools and commands locally
- **Local MCP servers**: Has access to user's locally configured MCP servers
- **Primary purpose**: Coding tasks and any work requiring local filesystem access
- **Session management**: Supports automatic session resumption across invocations

### Chat Cog

The `chat` cog provides "pure" LLM interaction without local system access:

- **No local filesystem access**: Cannot read or write local files
- **No local tool execution**: Cannot run tools or commands on the local machine
- **Cloud-based capabilities**: Can access cloud-based tools and MCP servers provided by the LLM provider
- **Primary purpose**: LLM reasoning tasks that don't require local filesystem access
- **Session management**: Does not currently provide automatic conversation resume or memory capability (not yet implemented, not a design limitation)

### Key Distinction

**Neither cog is more or less capable in terms of deep thinking or reasoning.** Both can perform complex reasoning tasks. The primary distinction is **local filesystem access and the ability to run locally-configured tools and MCP servers**.

### Documentation Guidelines

When documenting these cogs:

- **Don't** characterize `chat` as "simple" or `agent` as more capable of reasoning
- **Do** emphasize the environmental differences (local vs cloud-based execution)
- **Do** explain that `agent` is designed for tasks requiring local filesystem access
- **Do** explain that `chat` is designed for pure LLM reasoning without local system interaction
- **Don't** imply that `chat` is limited in reasoning capability - it's just limited in local system access
