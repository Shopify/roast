# Retry Example

This example demonstrates how to use the `retries` configuration option to automatically retry steps that fail.

## Features

- **Automatic retries**: Steps can be configured to retry a specified number of times
- **Works with exit_on_error**: Retries only happen when `exit_on_error` is true (default)
- **Command and custom steps**: Retries work for both command steps and custom steps

## Configuration

```yaml
step_name:
  retries: 3  # Number of times to retry on failure (default: 0)
  exit_on_error: true  # Whether to exit workflow on failure (default: true)
```

## How it works

1. When a step fails and has `retries` configured, it will automatically retry
2. Each retry attempt is logged to stderr
3. If all retries are exhausted and the step still fails:
   - If `exit_on_error: true` (default), the workflow will exit
   - If `exit_on_error: false`, the workflow will continue

## Example output

```
Executing: check_network
❌ Command failed: $(curl -f -s -o /dev/null -w '%{http_code}' https://httpstat.us/500)
   Exit status: 22
   Command failed, will retry (3 retries remaining)
Retrying: check_network (attempt 2/4)
❌ Command failed: $(curl -f -s -o /dev/null -w '%{http_code}' https://httpstat.us/500)
   Exit status: 22
   Command failed, will retry (2 retries remaining)
Retrying: check_network (attempt 3/4)
...
```

## Use cases

- Network requests that might fail transiently
- API calls with rate limiting
- File operations that might have timing issues
- Database operations that might have deadlocks
- Any operation that might fail due to temporary conditions