These examples demonstrate the Ruby DSL for Roast workflows. They are automatically tested to ensure they remain functional (see `test/functional/roast_examples_test.rb`).

Run examples with:
```bash
bundle exec bin/roast execute examples/basic_prompt_workflow.rb --executor dsl
```

## Available Examples

### basic_prompt_workflow.rb

Demonstrates using agent steps to analyze business data from a CSV file. Shows how to structure a simple multi-step analysis workflow.

### grading.rb

A comprehensive test evaluation workflow that uses parallel execution, JSON parsing, and multiple AI models. Demonstrates advanced DSL features like `map`, `ruby` cogs, and complex data flow.

### code_health.rb

**Code Health Analyzer** - Analyzes Ruby project quality, structure, and maintainability. Demonstrates practical use of DSL features like agent coordination, Ruby data processing, and comprehensive reporting. Works on any Ruby project including Roast itself.

### docs_generator.rb

**Documentation Generator** - Scans code and generates documentation suggestions for Ruby projects. Shows file analysis patterns, content generation workflows, and documentation assessment. Useful for improving project documentation quality.

### dependency_audit.rb

**Dependency Audit** - Analyzes Ruby project dependencies for security vulnerabilities and outdated packages. Demonstrates system command integration with `bundle audit` and `bundle outdated`, plus dependency health assessment patterns.

### git_insights.rb

**Git Repository Insights** - Analyzes git repository history for development patterns, contributor activity, and project health metrics. Shows git command integration and data analysis workflows that work on any git repository.

### issue_triage.rb

**Issue Triage Helper** - Analyzes GitHub issues and provides categorization and prioritization suggestions. Demonstrates GitHub CLI integration and text analysis patterns. Requires `gh` CLI tool and GitHub authentication.
