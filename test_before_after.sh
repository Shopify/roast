#!/bin/bash

echo "🔍 BEFORE/AFTER ErrorFormatter Comparison"
echo "========================================"
echo
echo "This branch shows the BEFORE behavior (raw stack traces and async noise)"
echo "Compare with mathiusj/error-formatter-examples to see the AFTER behavior"
echo
echo "----------------------------------------"
echo

echo "1. Testing valid workflow:"
echo "bin/roast execute test_valid_workflow.rb --executor dsl"
bin/roast execute test_valid_workflow.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "2. Testing missing input (should show raw stack trace):"
echo "bin/roast execute test_missing_input.rb --executor dsl"
bin/roast execute test_missing_input.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "3. Testing undefined method (should show raw stack trace):"
echo "bin/roast execute test_undefined_method.rb --executor dsl"
bin/roast execute test_undefined_method.rb --executor dsl
echo
echo "----------------------------------------"
echo

echo "🚨 BEFORE: Notice the verbose async warnings and raw Ruby stack traces above"
echo "✅ AFTER: Check mathiusj/error-formatter-examples branch for clean user-friendly messages"