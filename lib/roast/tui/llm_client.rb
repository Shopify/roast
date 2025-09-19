# typed: true
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Roast
  module TUI
    class LLMClient
      DEFAULT_BASE_URL = "https://api.openai.com/v1"
      DEFAULT_MODEL = "claude-opus-4-1"
      MAX_RETRIES = 3
      RETRY_DELAY = 1

      attr_reader :base_url, :api_key, :model, :tool_registry

      def initialize(api_key: nil, base_url: nil, model: nil, tool_registry: nil)
        @api_key = api_key || ENV["OPENAI_API_KEY"]
        @base_url = base_url || ENV["OPENAI_BASE_URL"] || DEFAULT_BASE_URL
        @model = model || ENV["OPENAI_MODEL"] || DEFAULT_MODEL
        @tool_registry = tool_registry || ToolRegistry.new

        raise ArgumentError, "API key is required" unless @api_key
      end

      # Main chat completion method with tool calling support
      def chat_completion(messages, stream: false, temperature: 0.7, max_tokens: nil)
        request_body = build_request_body(messages, stream, temperature, max_tokens)
        
        if stream
          stream_completion(request_body) do |chunk|
            yield chunk if block_given?
          end
        else
          response = make_request(request_body)
          LLMResponse.new(response)
        end
      end

      # Execute a completion with automatic tool handling
      def chat_with_tools(messages, max_iterations: 10, &block)
        iterations = 0
        current_messages = messages.dup

        while iterations < max_iterations
          iterations += 1

          response = chat_completion(current_messages, stream: false)
          
          # Add assistant's message to history
          current_messages << response.to_message

          # Check if we need to execute tools
          if response.has_tool_calls?
            tool_results = execute_tools(response.tool_calls, &block)
            
            # Add tool results to messages
            tool_results.each do |result|
              current_messages << {
                role: "tool",
                tool_call_id: result[:tool_call_id],
                content: result[:content]
              }
            end
          else
            # No more tool calls, return final response
            return response
          end
        end

        raise "Maximum tool calling iterations (#{max_iterations}) reached"
      end

      # Stream completion with tool call support
      def stream_with_tools(messages, &block)
        current_messages = messages.dup
        accumulated_response = LLMResponse::StreamAccumulator.new

        stream_completion(build_request_body(current_messages, true)) do |chunk|
          accumulated_response.add_chunk(chunk)
          
          # Yield progress to caller
          yield({ type: :chunk, data: chunk }) if block_given?

          # Check if we've completed a tool call
          if accumulated_response.complete_tool_call?
            tool_call = accumulated_response.get_tool_call
            
            # Yield tool start event
            tool_name = tool_call[:function][:name]
            arguments = JSON.parse(tool_call[:function][:arguments]) rescue {}
            yield({ type: :tool_start, name: tool_name, arguments: arguments }) if block_given?
            
            # Execute the tool
            result = execute_single_tool(tool_call)
            
            # Yield tool execution result
            yield({ type: :tool_complete, name: tool_name, result: result[:content] }) if block_given?

            # Add to messages and continue
            current_messages << accumulated_response.to_message
            current_messages << {
              role: "tool",
              tool_call_id: tool_call[:id],
              content: result[:content]
            }

            # Reset accumulator and continue streaming
            accumulated_response = LLMResponse::StreamAccumulator.new
            stream_completion(build_request_body(current_messages, true)) do |next_chunk|
              accumulated_response.add_chunk(next_chunk)
              yield({ type: :chunk, data: next_chunk }) if block_given?
            end
          end
        end

        accumulated_response
      end

      private

      def build_request_body(messages, stream, temperature = 0.7, max_tokens = nil)
        body = {
          model: @model,
          messages: messages,
          stream: stream,
          temperature: temperature
        }

        body[:max_tokens] = max_tokens if max_tokens

        # Add tools if registered
        if @tool_registry.has_tools?
          body[:tools] = @tool_registry.to_openai_format
          body[:tool_choice] = "auto"
        end

        body
      end

      def make_request(body, retries = 0)
        uri = URI.parse("#{@base_url}/chat/completions")
        http = build_http_client(uri)
        request = build_request(uri, body)

        response = http.request(request)
        
        case response.code.to_i
        when 200
          JSON.parse(response.body)
        when 429, 500, 502, 503, 504
          if retries < MAX_RETRIES
            sleep(RETRY_DELAY * (2 ** retries))
            make_request(body, retries + 1)
          else
            raise "API request failed after #{MAX_RETRIES} retries: #{response.code} #{response.body}"
          end
        else
          raise "API request failed: #{response.code} #{response.body}"
        end
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        if retries < MAX_RETRIES
          sleep(RETRY_DELAY * (2 ** retries))
          make_request(body, retries + 1)
        else
          raise "API request timed out after #{MAX_RETRIES} retries: #{e.message}"
        end
      end

      def stream_completion(body, &block)
        uri = URI.parse("#{@base_url}/chat/completions")
        http = build_http_client(uri)
        request = build_request(uri, body)

        http.request(request) do |response|
          unless response.code.to_i == 200
            raise "Streaming request failed: #{response.code} #{response.read_body}"
          end

          buffer = ""
          response.read_body do |chunk|
            buffer += chunk
            
            # Process complete SSE events
            while (line_end = buffer.index("\n"))
              line = buffer[0...line_end]
              buffer = buffer[(line_end + 1)..-1]
              
              next if line.strip.empty?
              next unless line.start_with?("data: ")
              
              data = line[6..-1].strip
              next if data == "[DONE]"
              
              begin
                parsed = JSON.parse(data)
                yield parsed
              rescue JSON::ParserError => e
                # Log but don't fail on parse errors
                warn "Failed to parse SSE chunk: #{e.message}"
              end
            end
          end
        end
      end

      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 30
        http.read_timeout = 300
        http.write_timeout = 300
        http
      end

      def build_request(uri, body)
        request = Net::HTTP::Post.new(uri.path)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "text/event-stream" if body[:stream]
        request.body = JSON.generate(body)
        request
      end

      def execute_tools(tool_calls, &block)
        # Execute tools in parallel for better performance
        if tool_calls.size > 1 && @tool_registry.supports_parallel?
          execute_tools_parallel(tool_calls, &block)
        else
          execute_tools_sequential(tool_calls, &block)
        end
      end

      def execute_tools_sequential(tool_calls, &block)
        tool_calls.map do |tool_call|
          execute_single_tool(tool_call, &block)
        end
      end

      def execute_tools_parallel(tool_calls, &block)
        concurrent_available = begin
          require "concurrent"
          true
        rescue LoadError
          false
        end
        
        if concurrent_available
          promises = tool_calls.map do |tool_call|
            Concurrent::Promise.execute do
              execute_single_tool(tool_call, &block)
            end
          end
          
          promises.map(&:value!)
        else
          # Fall back to sequential execution if Concurrent is not available
          tool_calls.map { |tool_call| execute_single_tool(tool_call, &block) }
        end
      end

      def execute_single_tool(tool_call, &block)
        tool_name = tool_call[:function][:name]
        arguments = JSON.parse(tool_call[:function][:arguments])
        
        # Notify caller about tool execution
        yield({ type: :tool_start, name: tool_name, arguments: arguments }) if block_given?
        
        begin
          result = @tool_registry.execute(tool_name, arguments)
          content = result.is_a?(String) ? result : JSON.generate(result)
          
          yield({ type: :tool_complete, name: tool_name, result: content }) if block_given?
          
          {
            tool_call_id: tool_call[:id],
            content: content
          }
        rescue => e
          error_message = "Tool execution failed: #{e.message}"
          
          yield({ type: :tool_error, name: tool_name, error: error_message }) if block_given?
          
          {
            tool_call_id: tool_call[:id],
            content: error_message
          }
        end
      end
    end
  end
end