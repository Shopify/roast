# ErrorFormatter Before/After Comparison

This branch demonstrates the **BEFORE** behavior - what DSL error messages look like without the ErrorFormatter implementation.

## Quick Test
```bash
./test_before_after.sh
```

## Expected BEFORE Behavior (this branch):
- ❌ **Verbose async warnings** with full internal stack traces
- ❌ **Raw Ruby exceptions** exposing internal gem paths
- ❌ **Multiple duplicate error messages** from async task failures
- ❌ **Confusing technical details** instead of actionable error messages

## Compare with AFTER Behavior:
Switch to the `mathiusj/error-formatter-examples` branch to see the improved ErrorFormatter behavior:

```bash
git checkout mathiusj/error-formatter-examples
./test_error_formatter.sh
```

## Expected AFTER Behavior (ErrorFormatter branch):
- ✅ **Clean user-friendly messages** like "❌ Cog Input Validation Failed"
- ✅ **No async noise** - verbose logging suppressed
- ✅ **Actionable solutions** - tells users exactly what to fix
- ✅ **Single clear error** per problem

## Test Files
- `test_valid_workflow.rb` - Should work normally on both branches
- `test_missing_input.rb` - Shows input validation error (raw vs formatted)
- `test_undefined_method.rb` - Shows undefined method error (raw vs formatted)