# ErrorFormatter Demo Examples

This branch contains demo examples for manually testing the ErrorFormatter functionality implemented in PR #525.

## Quick Demo

```bash
./test_error_formatter.sh
```

## Test Files

- **`test_valid_workflow.rb`** - Valid DSL workflow (shows "Hello World" + "Goodbye")
- **`test_missing_input.rb`** - Input validation error (Chat cog missing 'prompt')
- **`test_undefined_method.rb`** - Undefined method error (typo in DSL method name)
- **`test_config_error.rb`** - Configuration error (nonexistent working directory)
- **`test_runtime_error.rb`** - Runtime execution error (command not found)

## Individual Tests

```bash
# Valid workflow (should show output)
bin/roast execute test_valid_workflow.rb --executor dsl

# Input validation error
bin/roast execute test_missing_input.rb --executor dsl

# Undefined method error
bin/roast execute test_undefined_method.rb --executor dsl

# Configuration error
bin/roast execute test_config_error.rb --executor dsl

# Runtime execution error
bin/roast execute test_runtime_error.rb --executor dsl
```

## What You'll See

✅ **Clean user-friendly messages** like "❌ Cog Input Validation Failed"
✅ **No verbose async logging** cluttering the output
✅ **Actionable solutions** telling users exactly what to fix
✅ **Single clear error per problem** instead of duplicate messages

## Error Types Covered

🎯 **Input validation** - Missing required parameters
🎯 **Undefined methods** - Typos in DSL method names
🎯 **Configuration errors** - Invalid cog settings
🎯 **Runtime errors** - Command execution failures

## Note

These files are for manual testing and demonstration only. They should not be shipped to production.