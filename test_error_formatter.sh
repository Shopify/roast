#!/bin/bash

echo "🧪 DSL Error Demo - Raw Behavior (WITHOUT ErrorFormatter)"
echo "========================================================"
echo

echo "1. ✅ Valid Workflow (should show output):"
echo "bin/roast execute test_valid_workflow.rb --executor dsl"
bin/roast execute test_valid_workflow.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "2. 📝 Input Validation Error (will show raw async stack traces):"
echo "bin/roast execute test_missing_input.rb --executor dsl"
bin/roast execute test_missing_input.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "3. ❓ Undefined Method Error (will show raw async stack traces):"
echo "bin/roast execute test_undefined_method.rb --executor dsl"
bin/roast execute test_undefined_method.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "4. ⚙️ Configuration Error (will show raw stack traces):"
echo "bin/roast execute test_config_error.rb --executor dsl"
bin/roast execute test_config_error.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "5. 💥 Runtime Execution Error (will show raw stack traces):"
echo "bin/roast execute test_runtime_error.rb --executor dsl"
bin/roast execute test_runtime_error.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "🚨 Raw behavior: Notice the verbose async warnings and Ruby stack traces above"
echo "🎯 Compare with mathiusj/error-formatter-examples branch to see clean error formatting!"