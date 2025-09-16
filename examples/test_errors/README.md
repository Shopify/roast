# Unified Error Testing for Enhanced Error Handling

This directory contains a unified testing approach for the enhanced error handling feature.

## Files

- `mock_server.rb` - Single mock server that simulates all error types
- `workflow.yml` - Single workflow that tests any error type via environment variable

## Usage

### Step 1: Start the Unified Mock Server

```bash
ruby examples/test_errors/mock_server.rb
```

This starts a single server on port 8080 that handles all error types.

### Step 2: Test Different Error Types

Set the API base URL with the error code you want to test:

```bash
# Test 500 Internal Server Error
export OPENAI_API_BASE="http://localhost:8080/v1/500"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml

# Test 503 Service Unavailable
export OPENAI_API_BASE="http://localhost:8080/v1/503"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml

# Test 429 Rate Limiting
export OPENAI_API_BASE="http://localhost:8080/v1/429"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml

# Test 502 Bad Gateway
export OPENAI_API_BASE="http://localhost:8080/v1/502"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml

# Test 401 Unauthorized
export OPENAI_API_BASE="http://localhost:8080/v1/401"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml

# Test 404 Not Found
export OPENAI_API_BASE="http://localhost:8080/v1/404"
export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

## Available Endpoints

The unified server provides these endpoints:

- `/v1/500/chat/completions` - Returns 500 Internal Server Error
- `/v1/503/chat/completions` - Returns 503 Service Unavailable
- `/v1/429/chat/completions` - Returns 429 Rate Limiting
- `/v1/502/chat/completions` - Returns 502 Bad Gateway
- `/v1/401/chat/completions` - Returns 401 Unauthorized
- `/v1/404/chat/completions` - Returns 404 Not Found
- `/v1/timeout/chat/completions` - Simulates timeout

## Expected Output

Each test will show the enhanced error message format:

```
Error: API call to http://localhost:8080/v1/{status}/chat/completions failed with status {status}:
the server responded with status {status} (Response: {detailed error message})
```

## Complete Test Examples

### Terminal 1: Start the Server Once

```bash
ruby examples/test_errors/mock_server.rb
```

### Terminal 2: Run All Tests

#### 500 Internal Server Error

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/500" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/500/chat/completions failed with status 500:
the server responded with status 500 (Response: Internal server error: Database connection failed - Unable to establish connection to primary database after 3 retry attempts. Connection pool exhausted.)
```

#### 503 Service Unavailable

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/503" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/503/chat/completions failed with status 503:
the server responded with status 503 (Response: Service temporarily unavailable due to high load. Please retry after 30 seconds.)
```

#### 429 Rate Limiting

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/429" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/429/chat/completions failed with status 429:
the server responded with status 429 (Response: Rate limit exceeded. You have made too many requests. Please wait 60 seconds before making another request.)
```

#### 502 Bad Gateway

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/502" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/502/chat/completions failed with status 502:
the server responded with status 502 (Response: Bad Gateway: The upstream server failed to respond. The proxy server received an invalid response from the upstream server.)
```

#### 401 Unauthorized

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/401" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/401/chat/completions failed with status 401:
the server responded with status 401 (Response: Invalid API key provided. Please check your API key and try again.)
```

#### 404 Not Found

```bash
export OPENAI_API_BASE="http://localhost:8080/v1/404" && export OPENAI_API_KEY="test-key"
bin/roast execute examples/test_errors/workflow.yml
```

Expected output:

```
Error: API call to http://localhost:8080/v1/404/chat/completions failed with status 404:
the server responded with status 404 (Response: The requested model does not exist or you do not have access to it.)
```

## Quick Test All Script

```bash
#!/bin/bash
# Start server in background
ruby examples/test_errors/mock_server.rb &
SERVER_PID=$!
sleep 2

# Test all error codes
for code in 500 503 429 502 401 404; do
  echo "Testing $code error..."
  export OPENAI_API_BASE="http://localhost:8080/v1/$code"
  export OPENAI_API_KEY="test-key"
  bin/roast execute examples/test_errors/workflow.yml 2>&1 | grep "Error:"
done

# Kill server
kill $SERVER_PID
```

## Benefits

- **Single server** for all error types (no port conflicts)
- **Single workflow** with parameterized endpoint
- **Clean and simple** - just 2 files instead of 30+
- **Easy to extend** - add new error types to the server
