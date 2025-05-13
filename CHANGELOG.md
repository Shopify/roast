# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
