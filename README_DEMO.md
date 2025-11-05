# DSL Error Demo - Raw Behavior

This branch shows the **current (raw)** behavior of DSL errors WITHOUT the ErrorFormatter.

## Quick Demo

```bash
./test_error_formatter.sh
```

## What You'll See

❌ **Verbose async warnings** with full internal stack traces
❌ **Raw Ruby exceptions** exposing internal gem paths
❌ **Multiple duplicate error messages** from async task failures
❌ **Confusing technical details** instead of actionable error messages

## Compare With ErrorFormatter

Switch to `mathiusj/error-formatter-examples` to see the improved behavior:

```bash
git checkout mathiusj/error-formatter-examples
./test_error_formatter.sh
```

## Test Files

- `test_valid_workflow.rb` - Valid DSL workflow (works on both branches)
- `test_missing_input.rb` - Input validation error (raw vs formatted)
- `test_undefined_method.rb` - Undefined method error (raw vs formatted)
- `test_config_error.rb` - Configuration error (raw vs formatted)
- `test_runtime_error.rb` - Runtime execution error (raw vs formatted)

## Note

This branch is based on main (without ErrorFormatter) and shows the current error experience for comparison purposes.