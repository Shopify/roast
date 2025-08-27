# Test Enhanced Error Messages

This example demonstrates the enhanced error messaging feature from PR #389.

## Usage

Run with an invalid API key to see the enhanced error:

```bash
OPENAI_API_KEY="invalid-key" bin/roast execute examples/test_enhanced_errors/workflow.yml
```

Or let it use the default invalid key:

```bash
bin/roast execute examples/test_enhanced_errors/workflow.yml
```

## Expected Output

You should see an enhanced error message that includes:
- The API endpoint URL
- The HTTP status code  
- The error response body

Instead of just: `the server responded with status 401`

**Note:** This example can be removed after testing.