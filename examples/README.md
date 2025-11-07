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
