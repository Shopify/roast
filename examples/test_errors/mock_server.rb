#!/usr/bin/env ruby
# frozen_string_literal: true

# Unified mock server that returns different errors based on endpoint
# Usage: ruby unified_mock_server.rb

require "webrick"

class UnifiedMockServer < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    puts "Received request to #{request.path}"
    
    case request.path
    when "/v1/500/chat/completions"
      handle_500_error(response)
    when "/v1/503/chat/completions"
      handle_503_error(response)
    when "/v1/429/chat/completions"
      handle_429_error(response)
    when "/v1/502/chat/completions"
      handle_502_error(response)
    when "/v1/timeout/chat/completions"
      handle_timeout(response)
    when "/v1/401/chat/completions"
      handle_401_error(response)
    when "/v1/404/chat/completions"
      handle_404_error(response)
    else
      response.status = 404
      response.body = "Unknown endpoint: #{request.path}"
    end
  end
  
  private
  
  def handle_500_error(response)
    response.status = 500
    response["Content-Type"] = "application/json"
    response.body = <<~JSON
      {
        "error": {
          "message": "Internal server error: Database connection failed - Unable to establish connection to primary database after 3 retry attempts. Connection pool exhausted.",
          "type": "server_error",
          "param": null,
          "code": "internal_error"
        }
      }
    JSON
    puts "Returning 500 Internal Server Error"
  end
  
  def handle_503_error(response)
    response.status = 503
    response["Content-Type"] = "application/json"
    response["Retry-After"] = "30"
    response.body = <<~JSON
      {
        "error": {
          "message": "Service temporarily unavailable due to high load. Please retry after 30 seconds.",
          "type": "service_unavailable",
          "param": null,
          "code": "service_unavailable"
        }
      }
    JSON
    puts "Returning 503 Service Unavailable"
  end
  
  def handle_429_error(response)
    response.status = 429
    response["Content-Type"] = "application/json"
    response["Retry-After"] = "60"
    response["X-RateLimit-Limit"] = "10000"
    response["X-RateLimit-Remaining"] = "0"
    response["X-RateLimit-Reset"] = (Time.now.to_i + 60).to_s
    response.body = <<~JSON
      {
        "error": {
          "message": "Rate limit exceeded. You have made too many requests. Please wait 60 seconds before making another request.",
          "type": "rate_limit_error",
          "param": null,
          "code": "rate_limit_exceeded"
        }
      }
    JSON
    puts "Returning 429 Rate Limit Exceeded"
  end
  
  def handle_502_error(response)
    response.status = 502
    response["Content-Type"] = "application/json"
    response.body = <<~JSON
      {
        "error": {
          "message": "Bad Gateway: The upstream server failed to respond. The proxy server received an invalid response from the upstream server.",
          "type": "bad_gateway",
          "param": null,
          "code": "bad_gateway"
        }
      }
    JSON
    puts "Returning 502 Bad Gateway"
  end
  
  def handle_401_error(response)
    response.status = 401
    response["Content-Type"] = "application/json"
    response.body = <<~JSON
      {
        "error": {
          "message": "Invalid API key provided. Please check your API key and try again.",
          "type": "authentication_error",
          "param": null,
          "code": "invalid_api_key"
        }
      }
    JSON
    puts "Returning 401 Unauthorized"
  end
  
  def handle_404_error(response)
    response.status = 404
    response["Content-Type"] = "application/json"
    response.body = <<~JSON
      {
        "error": {
          "message": "The requested model does not exist or you do not have access to it.",
          "type": "not_found_error",
          "param": "model",
          "code": "model_not_found"
        }
      }
    JSON
    puts "Returning 404 Not Found"
  end
  
  def handle_timeout(response)
    puts "Simulating timeout - sleeping for 65 seconds..."
    sleep(65)
    # This response will likely never be sent due to client timeout
    response.status = 200
    response["Content-Type"] = "application/json"
    response.body = '{"choices": [{"message": {"content": "This should timeout"}}]}'
  end
end

# Start the unified mock server
server = WEBrick::HTTPServer.new(Port: 8080)
server.mount "/", UnifiedMockServer
trap("INT") { server.shutdown }

puts "🔥 Unified Mock Error Server running on http://localhost:8080"
puts "Available endpoints:"
puts "  - /v1/500/chat/completions - Returns 500 Internal Server Error"
puts "  - /v1/503/chat/completions - Returns 503 Service Unavailable"
puts "  - /v1/429/chat/completions - Returns 429 Rate Limiting"
puts "  - /v1/502/chat/completions - Returns 502 Bad Gateway"
puts "  - /v1/401/chat/completions - Returns 401 Unauthorized"
puts "  - /v1/404/chat/completions - Returns 404 Not Found"
puts "  - /v1/timeout/chat/completions - Simulates timeout"
puts "Press Ctrl+C to stop"
server.start