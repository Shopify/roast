# Retry Configuration

Roast supports configurable retry mechanisms for handling transient failures in workflow steps. This feature helps improve reliability when dealing with rate-limited or temporarily unavailable services.

## Basic Usage

### Simple Retry Configuration

The simplest way to enable retries is to specify the number of retry attempts:

```yaml
steps:
  - fetch_data: "Fetch data from API"

fetch_data:
  retry: 3  # Retry up to 3 times with exponential backoff
```

### Detailed Configuration

For more control, you can specify detailed retry parameters:

```yaml
analyze_code:
  retry:
    strategy: exponential    # or 'linear', 'constant'
    max_attempts: 5         # Maximum number of retry attempts
    base_delay: 1.0         # Initial delay in seconds
    max_delay: 60.0         # Maximum delay between retries
    jitter: true            # Add randomization to delays
```

## Retry Strategies

### Exponential Backoff (Default)

Delays increase exponentially between retries:

```yaml
step_name:
  retry:
    strategy: exponential
    base_delay: 1.0         # First retry after 1 second
    multiplier: 2.0         # Double the delay each time
    max_delay: 30.0         # Cap at 30 seconds
    jitter: true            # Add 0-25% random variation
```

Delay calculation: `base_delay * (multiplier ^ (attempt - 1))`

### Linear Backoff

Delays increase linearly between retries:

```yaml
step_name:
  retry:
    strategy: linear
    base_delay: 2.0         # First retry after 2 seconds
    increment: 1.0          # Add 1 second each retry
    max_delay: 10.0         # Cap at 10 seconds
```

Delay calculation: `base_delay + (increment * (attempt - 1))`

### Constant Delay

Fixed delay between all retries:

```yaml
step_name:
  retry:
    strategy: constant
    base_delay: 5.0         # Always wait 5 seconds between retries
```

## Retryable Errors

By default, the following errors are considered retryable:
- Network timeouts (`Net::ReadTimeout`, `Net::OpenTimeout`, `Timeout::Error`)
- Rate limit errors (messages containing "rate limit")
- Temporary unavailability (messages containing "temporarily unavailable")
- Server errors (messages containing "server error")

## Disabling Retries

### For Specific Steps

To disable retries for a specific step:

```yaml
create_payment:
  retry: false              # Never retry this step
```

### For Non-Idempotent Operations

Mark steps that should not be retried due to side effects:

```yaml
send_email:
  idempotent: false         # Prevents retries even if retry config exists
  retry: 3                  # This will be ignored due to idempotent: false
```

## Examples

### API Call with Exponential Backoff

```yaml
name: api_integration
steps:
  - fetch_weather: "Get current weather data"

fetch_weather:
  retry:
    strategy: exponential
    max_attempts: 5
    base_delay: 0.5
    max_delay: 16.0
    jitter: true
```

### Database Query with Linear Backoff

```yaml
query_database:
  retry:
    strategy: linear
    max_attempts: 3
    base_delay: 1.0
    increment: 2.0    # 1s, 3s, 5s delays
```

### Critical Operation with Minimal Retries

```yaml
process_transaction:
  retry:
    strategy: constant
    max_attempts: 2
    base_delay: 0.1   # Quick retry for critical operations
```

### Inline Prompt with Retry

```yaml
steps:
  - analyze: |
      Analyze this codebase and identify performance bottlenecks.
      Focus on database queries and API calls.

analyze:
  model: gpt-4o
  retry: 3            # Simple retry configuration
```

## Monitoring and Debugging

Retry attempts are logged and instrumented:

1. **Log Output**: Each retry attempt is logged with the error and delay
2. **Instrumentation**: ActiveSupport notifications are sent for each retry:
   - Event: `roast.retry.attempt`
   - Payload: `{ attempt:, error:, message:, delay: }`

## Best Practices

1. **Start Conservative**: Begin with fewer retries and increase if needed
2. **Use Jitter**: Enable jitter to prevent thundering herd problems
3. **Set Reasonable Delays**: Balance between quick recovery and avoiding rate limits
4. **Mark Non-Idempotent Steps**: Always mark steps with side effects as `idempotent: false`
5. **Monitor Retries**: Track retry patterns to identify persistent issues
6. **Consider Circuit Breakers**: For frequently failing services, implement circuit breakers in your steps