#!/bin/bash

echo "🧪 ErrorFormatter Demo - All Error Types"
echo "========================================"
echo

echo "1. ✅ Valid Workflow (should show output):"
echo "bin/roast execute test_valid_workflow.rb --executor dsl"
bin/roast execute test_valid_workflow.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "2. 📝 Input Validation Error:"
echo "bin/roast execute test_missing_input.rb --executor dsl"
bin/roast execute test_missing_input.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "3. ❓ Undefined Method Error:"
echo "bin/roast execute test_undefined_method.rb --executor dsl"
bin/roast execute test_undefined_method.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "4. ⚙️ Configuration Error:"
echo "bin/roast execute test_config_error.rb --executor dsl"
bin/roast execute test_config_error.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "5. 💥 Runtime Execution Error:"
echo "bin/roast execute test_runtime_error.rb --executor dsl"
bin/roast execute test_runtime_error.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "✅ Demo completed! Notice the clean user-friendly error messages above."
echo "🎯 ErrorFormatter handles: Input validation • Undefined methods • Config errors • Runtime errors"