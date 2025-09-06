# Step Unit Testing Framework Example

This example demonstrates how to use Roast's step unit testing framework to test individual workflow steps in isolation.

## Overview

The step testing framework provides:
- **Test harness** for running steps in isolation
- **Input/output validation** helpers
- **Performance testing** support
- **Coverage reporting** for steps
- **Base test case class** with DSL for common assertions

## Example Files

### `example_workflow_step.rb`
A sample workflow step that analyzes code quality. This step:
- Accepts a file path as input
- Calls the LLM to analyze code quality
- Returns a structured JSON response with score, issues, and suggestions
- Applies a quality threshold to determine pass/fail

### `example_step_test.rb`
Comprehensive tests for the code analysis step demonstrating:
- Basic success/failure testing
- Output format validation
- Schema validation
- Performance testing
- Edge case handling
- Deterministic output testing
- Coverage reporting

## Running the Example

```bash
# Run the example test
bundle exec ruby -Itest examples/step_testing/example_step_test.rb

# Run with verbose output
bundle exec ruby -Itest examples/step_testing/example_step_test.rb -v
```

## Key Testing Patterns

### 1. Basic Step Testing
```ruby
class MyStepTest < Roast::Workflow::Testing::StepTestCase
  test_step MyStep

  test "step produces expected output" do
    with_mock_response("Expected response")
    result = assert_step_succeeds
    assert_equal "Expected response", result.result
  end
end
```

### 2. Output Validation
```ruby
test "validates output structure" do
  with_mock_response({ "key" => "value" })
  
  assert_output_format(:hash)
  assert_required_fields(["key"])
  assert_output_schema({ key: { type: :string } })
end
```

### 3. Performance Testing
```ruby
test "meets performance requirements" do
  with_mock_response("Fast response")
  
  assert_performance(
    execution_time: 1.0,  # Max 1 second
    api_calls: 1,         # Exactly 1 API call
    tool_calls: 0         # No tool usage
  )
end
```

### 4. Error Handling
```ruby
test "handles errors gracefully" do
  harness.step.should_fail = true
  assert_step_fails({}, ExpectedError)
end
```

### 5. Tool Usage Validation
```ruby
test "uses required tools" do
  with_tools(["read_file", "grep"])
  with_mock_response("Result")
  
  assert_tools_used(["read_file"])
end
```

## Testing Best Practices

1. **Test in isolation**: Use mock responses instead of making real API calls
2. **Validate structure**: Test both successful and error cases
3. **Check performance**: Ensure steps meet performance requirements
4. **Test edge cases**: Empty inputs, large datasets, invalid formats
5. **Verify determinism**: Ensure consistent output for same input
6. **Monitor coverage**: Use coverage reports to ensure comprehensive testing

## Advanced Features

### Custom Test Harness Setup
```ruby
harness = Roast::Workflow::Testing.harness_for(MyStep)
harness.with_mock_response("Response")
       .with_tools(["grep"])
       .with_initial_state({ "context" => "value" })
       .configure(model: "gpt-4")

result = harness.execute
```

### Benchmarking
```ruby
results = Roast::Workflow::Testing.benchmark_step(
  MyStep,
  [{ model: "gpt-4" }, { model: "gpt-3.5" }],
  iterations: 10
)

results.each do |result|
  puts result[:performance_report]
end
```

### Coverage Reporting
```ruby
Roast::Workflow::Testing.enable!

# Run your tests...

puts Roast::Workflow::Testing.generate_report
Roast::Workflow::Testing.export_results("coverage.json")
```

## Integration with CI/CD

The testing framework can be integrated into your CI/CD pipeline:

```yaml
# .github/workflows/test.yml
- name: Run Step Tests
  run: bundle exec rake test:steps

- name: Generate Coverage Report
  run: bundle exec ruby -e "
    require 'roast/workflow/testing'
    Roast::Workflow::Testing.enable!
    # Run tests
    Roast::Workflow::Testing.export_results('step_coverage.json')
  "

- name: Upload Coverage
  uses: actions/upload-artifact@v2
  with:
    name: step-coverage
    path: step_coverage.json
```