# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Automatic retry functionality for steps**
  - New `retries` configuration parameter allows steps to automatically retry on failure
  - Works with both command steps and custom steps
  - Retries only occur when `exit_on_error` is true (default behavior)
  - Useful for handling transient failures in network requests, API calls, and file operations
  - Example: `retries: 3` will retry a failing step up to 3 times before giving up
- **Workflow name in step event payloads** (#333, #351)
  - Added `workflow_name` field to all step-related ActiveSupport::Notification events
  - Enables better tracking of which workflow a step belongs to in monitoring systems
  - Updated events: `roast.step.start`, `roast.step.complete`, `roast.step.error`

## [0.4.3] - 2025-07-10

### Changed
- **Updated to raix-openai-eight gem** - Upgraded from `raix` to `raix-openai-eight` gem which supports OpenAI Ruby client v8.1

## [0.4.2] - 2025-06-20

### Added
- **Multiline bash command support** (#289)
  - Enhanced CommandExecutor to properly handle commands spanning multiple lines
  - Enables sophisticated bash scripts in workflow steps
  - Maintains backward compatibility with single-line commands
- **Comprehensive shell security enhancements** (#289)
  - Smart interpolation that detects shell commands and escapes dangerous characters
  - Protection against shell injection for all major metacharacters:
    - Backslashes (`\`) to prevent path injection
    - Double quotes (`"`) to prevent breaking quoted contexts
    - Dollar signs (`$`) to prevent variable expansion
    - Backticks (`` ` ``) to prevent command substitution
  - Context-aware escaping only in shell commands, preserving text elsewhere
- **Early detection for missing Raix configuration** (#292)
  - Provides helpful error messages when Raix is not properly initialized
  - Shows example configuration for both OpenAI and OpenRouter
  - Prevents cryptic "undefined method 'chat' for nil" errors
- **Exit early feature for input steps** (#291)
  - Pressing Ctrl-C during input steps now exits cleanly
  - No more confusing stack traces when canceling input
- **Default --dangerously-skip-permissions flag for CodingAgent** (#290)
  - Avoids permission prompts during automated workflows
  - Improves workflow automation experience

### Fixed
- Test isolation issue causing CI failures (#289)
- Flaky test in StepExecutorRegistryTest due to executor registration conflicts (#289)
- Shell command interpolation security vulnerabilities (#289)
- Missing dependency declarations (cli-kit, sqlite3) (#292)

### Changed
- Updated cli-kit dependency to ~> 5.0 for better error handling
- Updated sqlite3 dependency to ~> 2.6 to resolve version conflicts

[0.4.2]: https://github.com/Shopify/roast/compare/v0.4.1...v0.4.2

## [0.4.1] - 2025-06-18

### Added
- **SQLite session storage** as the default storage backend (#252)
  - Provides better performance and advanced querying capabilities
  - Sessions are stored in `~/.roast/sessions.db` by default (configurable via `ROAST_SESSIONS_DB`)
  - New `roast sessions` command to list and filter stored sessions
  - New `roast session <id>` command to view detailed session information
  - Session cleanup with `roast sessions --cleanup --older-than <duration>`
  - Filter sessions by status, workflow name, or age
  - Maintains full backward compatibility with filesystem storage
- **`--file-storage` CLI option** to use legacy filesystem storage instead of SQLite
  - Use `-f` or `--file-storage` flag to opt into filesystem storage
  - Environment variable `ROAST_STATE_STORAGE=file` still supported for compatibility
- **Foundation for wait_for_event feature** (#251)
  - New `roast resume` command infrastructure for resuming paused workflows
  - Event storage and tracking in SQLite sessions table
- **Configurable agent step options** for CodingAgent (#266)
  - New `continue` option for agent steps to maintain session context across multiple agent invocations
  - New `include_context_summary` option to provide AI-generated workflow context summaries to agents
  - Context summaries are intelligently tailored to the agent's specific task using LLM analysis
  - Helps reduce token usage by including only relevant context information
- **Token consumption reporting** for step execution (#264)
  - Displays token usage (prompt and completion) after each step execution
  - Helps users monitor and optimize their LLM token consumption
  - Automatically enabled for all workflow runs
- **Timeout functionality for bash and cmd steps** (#261)
  - New `timeout` option for bash and cmd steps to prevent hanging commands
  - Configurable timeout duration in seconds
  - Commands are automatically terminated if they exceed the specified timeout
  - Prevents workflows from getting stuck on unresponsive commands
- **Claude Swarm tool integration** (#254)
  - New `Roast::Tools::Swarm` for integrating with Claude Swarm framework
  - Enables using Swarm's multi-agent orchestration capabilities within Roast workflows
  - Provides seamless handoffs between specialized AI agents
- **Workflow visualization with diagram command** (#256)
  - New `roast diagram` command to generate visual representations of workflows
  - Creates GraphViz-based diagrams showing workflow structure and flow
  - Supports both DOT format output and PNG/SVG image generation
  - Helps understand complex workflow logic at a glance
- **Comprehensive workflow validation** (#244)
  - New `roast validate` command to check workflow syntax and structure
  - Validates YAML syntax, step references, and configuration options
  - Provides detailed error messages for invalid workflows
  - Helps catch errors before running workflows
- **apply_diff tool** (#246)
  - New built-in tool for applying unified diff patches to files
  - Supports standard diff format for making precise file modifications
  - Enables AI models to suggest changes in diff format
  - More reliable than search-and-replace for complex edits
- **Model fallback mechanism** (#257)
  - Workflows without explicit model configuration now use a sensible default
  - Prevents errors when model is not specified at workflow or step level
  - Improves user experience for simple workflows
- **Context management foundation for auto-compaction** (#264)
  - Infrastructure for future automatic context size management
  - Enables intelligent token usage optimization in long-running workflows

### Changed
- Session storage now defaults to SQLite instead of filesystem
  - Existing filesystem sessions remain accessible when using `--file-storage` flag
  - No migration required - both storage backends can coexist

[0.4.1]: https://github.com/Shopify/roast/compare/v0.4.0...v0.4.1

## [0.4.0] - 2025-06-12

### Added
- **Input step type** for collecting user input during workflow execution (#154)
  - Interactive prompts pause workflow execution to collect user input
  - Supports multiple input types: `text` (default), `confirm`, `select`, and `password`
  - `confirm` type provides yes/no prompts with boolean results
  - `select` type allows choosing from a list of options
  - `password` type masks input for sensitive data using io/console
  - Input values are stored in workflow output and accessible via dot notation (e.g., `{{output.step_name}}`)
  - Integrates with CLI::UI for consistent formatting and user experience
- **Agent step type** for direct pass-through to coding agents (#151)
  - Steps prefixed with `^` send prompts directly to the CodingAgent tool
  - Supports both file-based and inline agent prompts
  - Bypasses LLM interpretation for precise agent instructions

### Fixed
- DotAccessHash array wrapping and template response handling
- CLI::UI formatting and color handling for better terminal output

## [0.3.1] - 2025-06-05

### Added
- Default `print_response: true` for the last step in a workflow (#100)
  - The last step now automatically prints its response unless explicitly configured otherwise
  - Helps newcomers who would otherwise see no output from their workflows
  - Works with all step types: string steps, hash steps with variable assignment, and conditional steps
  - Parallel steps and iteration steps are intelligently handled (no automatic output since there's no single "last" step)

### Fixed
- PromptStep now properly passes `print_response`, `json`, and `params` parameters to chat_completion

## [0.3.0] - 2025-06-04

### Changed
- **BREAKING**: Upgraded to Raix 1.0.0 (#141)
  - Removed the deprecated `loop` parameter from chat_completion calls
  - Raix 1.0 automatically continues after tool calls until providing a text response
  - All chat completions now return strings (no longer arrays or complex structures)
  - JSON responses are automatically parsed when `json: true` is specified
- **BREAKING**: Removed configurable `loop` and `auto_loop` options from workflow configuration (#140)
  - The `loop:` and `auto_loop:` YAML configuration options have been removed entirely
  - Looping behavior is now automatic: always enabled when tools are present, disabled when no tools exist
  - This simplifies the codebase and makes behavior more predictable
  - To migrate: remove any `loop: true/false` or `auto_loop: true/false` settings from your workflow YAML files

### Fixed
- Enhanced boolean coercion to treat empty strings as false
- Improved iterable coercion to handle JSON array strings
- Fixed all tests to work with Raix 1.0's string-only responses

## [0.2.3] - 2025-05-29

### Fixed
- Model inheritance for nested steps in iteration steps (#105)
  - Nested steps within `repeat` and `each` blocks now properly inherit model configuration
  - Configuration hierarchy works correctly: step-specific → workflow-level → default model
  - Previously, nested steps always used the default model regardless of configuration

## [0.2.2] - 2025-05-29

### Added
- Pre/post processing framework for workflows with `pre_processing` and `post_processing` sections (#86)
  - Support for `output.txt` ERB templates in post-processing phase for custom output formatting
  - Pre/post processing support for single-target workflows (not just multi-target)
  - Simplified access to pre-processing data in target workflows (removed `output` intermediary level)
- Verbose mode improvements for better debugging experience (#98)
  - Command outputs are now displayed when using the `--verbose` flag
  - Commands executed within conditional branches also show output in verbose mode
- User-friendly error reporting for workflow failures (#98)
  - Clear ❌ indicators when commands or steps fail
  - Command failures show exit status and output (no verbose needed for failures)
  - Step failures provide helpful context about what might be wrong
  - Exit handler displays actionable suggestions for resolving issues
- Automatic workflow discovery by name (#97)
  - Can now run workflows by name without full path: `roast execute my_workflow`
  - Automatically looks for `roast/my_workflow/workflow.yml` in current directory
- Configurable base URI for API endpoints (#83)

### Fixed
- Search file tool now correctly prefixes paths when searching (#92)
- Support for Ruby projects using ActiveSupport 7.0+ (#95)

### Changed
- ActiveSupport dependency relaxed to >= 7.0 for broader compatibility

## [0.2.1]

### Added
- Smart coercion defaults for boolean expressions based on step type
  - Ruby expressions (`{{expr}}`) default to regular boolean coercion
  - Bash commands (`$(cmd)`) default to exit code interpretation
  - Inline prompts and regular steps default to "smart" LLM-powered interpretation (looks for truthy or falsy language)
- Direct syntax for step configuration - `coerce_to` and other options are now specified directly on iteration steps

## [0.2.0] - 2025-05-26

### Added
- Conditional execution support with `if` and `unless` clauses for workflow steps
- Iteration mechanisms for workflows with `repeat` and `each` constructs (resolving issue #48)
- Support for conditional repetition with `until` condition and safety limits
- Collection iteration with variable binding for processing lists of items
- State persistence for loop iterations to enable resumption after failure
- Standardized evaluation of Ruby expressions in iteration constructs using `{{}}` syntax
- Support for using bash commands, step names, and Ruby expressions in iteration conditions and collections
- Intelligent LLM response to boolean conversion with pattern-based recognition for natural language responses
- `exit_on_error` configuration option for command steps to continue workflow on failure (resolving issue #71)
- Dot notation access for workflow outputs (e.g., `workflow.output.step.field`)
- `--pause` flag for stepping through workflow execution interactively

### Fixed
- Automatically add `.gitignore` file to cache directory when created (completing issue #22)
- Load initializers before trying to load tools in case custom tools are defined in initializers (thanks @palkan)
- Fix loading of targetless workflows (thanks @palkan)
- Fix OpenRouter support (thanks @xrendan)
- API authentication error handling and model access issues
- Conditional step transcript replay regression
- DotAccessHash serialization for AI prompts

### Improved
- Enhanced search file tool logging to show full expanded paths instead of relative paths
- Major refactoring to eliminate circular dependencies and improve architecture
- Extracted command execution logic into dedicated CommandExecutor class
- Separated conditional execution from iteration logic for better SOLID compliance
- Enhanced error messages for API authentication failures
- Replaced all `require_relative` with `require` statements for consistency

### Changed
- Refactored god objects to improve code organization and maintainability
- Improved separation of concerns between workflow components

[0.2.0]: https://github.com/Shopify/roast/compare/v0.1.7...v0.2.0

## [0.1.7] - 2024-05-16

### Added
- `UpdateFiles` tool for applying diffs/patches to multiple files at once
- Support for atomic file updates with rollback capability
- Comprehensive documentation for all built-in tools
- Enhanced README with detailed tool usage examples

``[0.1.7]: https://github.com/Shopify/roast/compare/v0.1.6...v0.1.7

## [0.1.6] - 2024-05-15

### Added
- Support for OpenRouter as an API provider
- `api_provider` configuration option allowing choice between OpenAI and OpenRouter
- Added separate CI rake task for improved build pipeline
- Version command to check current Roast version
- Walking up to home folder for config root
- Improved initializer support for better project configuration

### Changed
- Enhanced search tool to work with globs for more flexible searches
- Improved error handling in configuration and initializers
- Fixed and simplified interpolation examples

### Fixed
- Better error messages for search file tool
- Improved initializer loading and error handling
- Fixed tests for nested .roast folders

[0.1.6]: https://github.com/Shopify/roast/compare/v0.1.5...v0.1.6

## [0.1.5] - 2024-05-13

### Added
- Interpolation feature for dynamic workflows using `{{}}` syntax
- Support for injecting values from workflow context into step names and commands
- Ability to access file metadata and step outputs using interpolation expressions
- Examples demonstrating interpolation usage with different file types

[0.1.5]: https://github.com/Shopify/roast/releases/tag/v0.1.5

## [0.1.4] - 2024-05-13

### Fixed
- Remove test directory restriction from WriteTool. (Thank you @endoze)

[0.1.4]: https://github.com/Shopify/roast/releases/tag/v0.1.4


## [0.1.3] - 2024-05-12

### Fixed
- ReadFile tool now handles absolute and relative paths correctly

[0.1.3]: https://github.com/Shopify/roast/releases/tag/v0.1.3


## [0.1.2] - 2024-05-09

### Fixed
- problem with step loading using `--replay` option
- made access to `workflow.output` more robust by using hash with indifferent access

[0.1.2]: https://github.com/Shopify/roast/releases/tag/v0.1.2

## [0.1.1] - 2024-05-09

### Added
- Initial public release of Roast, extracted from Shopify's internal AI orchestration tools
- Core workflow execution engine for structured AI interactions
- Step-based workflow definition system
- Instrumentation hooks for monitoring and debugging
- Integration with various LLM providers (via [Raix](https://github.com/OlympiaAI/raix))
- Schema validation for workflow inputs and outputs
- Command-line interface for running workflows
- Comprehensive documentation and examples

[0.1.1]: https://github.com/Shopify/roast/releases/tag/v0.1.1
