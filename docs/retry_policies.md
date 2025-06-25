# Retry Policies in Roast

Roast provides configurable retry policies that allow you to automatically retry failed operations based on specific conditions. This improves reliability and handles transient failures gracefully.

## Overview

Retry policies can be configured at multiple levels:
- **Global level**: Applies to all steps in the workflow
- **Step level**: Applies to a specific step (overrides global)
- **API level**: Applies specifically to LLM API calls

## Basic Configuration

### Global Retry Policy

```yaml
# workflow.yml
name: my_workflow

# Global retry configuration
retry:
  strategy: exponential  # exponential, linear, or fixed
  max_attempts: 3
  base_delay: 1         # seconds
  max_delay: 60         # seconds
  jitter: true          # adds randomness to prevent thundering herd

steps:
  - analyze_data
  - generate_report
```

### Step-Specific Retry Policy

```yaml
# workflow.yml
name: my_workflow

steps:
  - fetch_api_data
  - process_results

# Step-specific configuration
fetch_api_data:
  retry:
    strategy: exponential
    max_attempts: 5
    base_delay: 2
    matcher:
      type: http_status
      statuses: [429, 502, 503, 504]
```

### API Retry Configuration

```yaml
# workflow.yml
name: my_workflow

# Retry configuration for LLM API calls
retry:
  api:
    strategy: exponential
    max_attempts: 3
    base_delay: 1
    max_delay: 30
    # API calls automatically retry on rate limits and common HTTP errors

steps:
  - generate_content
```

## Retry Strategies

### Exponential Backoff
Delay doubles with each attempt: 1s, 2s, 4s, 8s...

```yaml
retry:
  strategy: exponential
  base_delay: 1
  max_delay: 60
```

### Linear Backoff
Delay increases linearly: 1s, 2s, 3s, 4s...

```yaml
retry:
  strategy: linear
  base_delay: 1
  max_delay: 60
```

### Fixed Delay
Same delay between all attempts

```yaml
retry:
  strategy: fixed
  base_delay: 5
```

## Condition-Based Retry

### Error Type Matching
Retry only on specific error types:

```yaml
retry:
  strategy: exponential
  max_attempts: 3
  matcher:
    type: error_type
    errors: ["Faraday::TimeoutError", "Net::ReadTimeout"]
```

### Error Message Matching
Retry based on error message patterns:

```yaml
retry:
  strategy: exponential
  max_attempts: 3
  matcher:
    type: error_message
    pattern: "timeout|connection reset"  # regex pattern
```

### HTTP Status Matching
Retry on specific HTTP status codes:

```yaml
retry:
  strategy: exponential
  max_attempts: 5
  matcher:
    type: http_status
    statuses: [408, 429, 500, 502, 503, 504]
```

### Rate Limit Detection
Automatically detect and retry rate-limited requests:

```yaml
retry:
  strategy: exponential
  max_attempts: 5
  matcher:
    type: rate_limit
```

### Composite Matchers
Combine multiple conditions:

```yaml
retry:
  strategy: exponential
  max_attempts: 3
  matcher:
    type: composite
    operator: any  # 'any' or 'all'
    matchers:
      - type: http_status
        statuses: [429, 503]
      - type: error_message
        pattern: "rate limit"
```

## Custom Handlers

### Logging Handler
Logs retry attempts:

```yaml
retry:
  strategy: exponential
  max_attempts: 3
  handlers:
    - type: logging
```

### Instrumentation Handler
Sends retry metrics to monitoring:

```yaml
retry:
  strategy: exponential
  max_attempts: 3
  handlers:
    - type: instrumentation
      namespace: "my_app.retry"
```

## Complete Examples

### Robust API Integration

```yaml
name: api_integration_workflow

# Global retry for all steps
retry:
  strategy: exponential
  max_attempts: 3
  base_delay: 1
  jitter: true
  handlers:
    - type: logging
    - type: instrumentation

# API-specific retry configuration
retry:
  api:
    strategy: exponential
    max_attempts: 5
    base_delay: 2
    max_delay: 60

steps:
  - fetch_external_data
  - process_data
  - generate_summary

# Override for specific step
fetch_external_data:
  retry:
    strategy: exponential
    max_attempts: 10
    base_delay: 1
    matcher:
      type: composite
      operator: any
      matchers:
        - type: rate_limit
        - type: http_status
          statuses: [429, 502, 503, 504]
        - type: error_message
          pattern: "timeout|timed out"
```

### Command Execution with Retry

```yaml
name: deployment_workflow

steps:
  - run_tests
  - deploy_application
  - verify_deployment

run_tests:
  retry:
    strategy: fixed
    max_attempts: 2
    base_delay: 5
    matcher:
      type: error_message
      pattern: "flaky test|connection refused"

deploy_application:
  retry:
    strategy: exponential
    max_attempts: 3
    base_delay: 10
    max_delay: 60
```

## Best Practices

1. **Use exponential backoff** for external API calls to avoid overwhelming services
2. **Enable jitter** to prevent thundering herd problems
3. **Set reasonable max_attempts** - usually 3-5 is sufficient
4. **Configure max_delay** to prevent excessive wait times
5. **Use specific matchers** to retry only on recoverable errors
6. **Add logging handlers** for debugging and monitoring
7. **Test retry configurations** in development before production

## Monitoring and Metrics

When using retry policies, monitor these metrics:
- Total retry attempts
- Success rate after retries
- Average time to success
- Most common retry reasons

Use the instrumentation handler to send these metrics to your monitoring system.