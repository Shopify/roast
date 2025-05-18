# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
- Enhanced search file tool logging to show full expanded paths instead of relative paths


## [0.1.7] - 2024-05-16

### Added
- `UpdateFiles` tool for applying diffs/patches to multiple files at once
- Support for atomic file updates with rollback capability
- Comprehensive documentation for all built-in tools
- Enhanced README with detailed tool usage examples

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

[0.1.7]: https://github.com/Shopify/roast/compare/v0.1.6...v0.1.7
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
