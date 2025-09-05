# Test Grading Workflow

This workflow acts as a senior software engineer and testing expert to evaluate the quality of test files based on best practices and guidelines.

## Usage

```bash
# Run the grading workflow on a test file
roast execute examples/grading/workflow.yml path/to/your_test.rb
```

## How it Works

1. **read_dependencies**: Analyzes the test file and its dependencies
2. **run_coverage**: Executes the test with coverage tracking
3. **generate_grades**: Evaluates test quality across multiple dimensions
4. **verify_test_helpers**: Checks for proper test helper usage
5. **verify_mocks_and_stubs**: Ensures appropriate use of test doubles
6. **analyze_coverage**: Reviews code coverage metrics
7. **generate_recommendations**: Provides improvement suggestions
8. **calculate_final_grade**: Computes an overall grade (A-F scale)
9. **format_result**: Formats the final output

## Customization

Feel free to adapt this workflow to your testing environment:

- **Different test frameworks**: Modify `run_coverage.rb` to work with RSpec, Jest, pytest, etc.
- **Coverage tools**: Replace the coverage command with your preferred tool (SimpleCov, Istanbul, Coverage.py)
- **Grading criteria**: Adjust the prompts in each step to match your team's standards

## Example Output

```
========== TEST GRADE REPORT ==========
Test file: test/example_test.rb

FINAL GRADE:
  Score: 85/100
  Letter Grade: B

RECOMMENDATIONS:
- Add edge case testing for error conditions
- Improve test descriptions for clarity
- Consider extracting common setup to helper methods
```
