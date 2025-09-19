# typed: false
# frozen_string_literal: true

require "test_helper"
require "roast/tui/llm_client"
require "roast/tui/llm_response"
require "roast/tui/tool_registry"
require "roast/tui/configuration"
require "roast/tui/session_manager"
require "webmock/minitest"

module Roast
  module TUI
    class LLMClientTest < ActiveSupport::TestCase
      setup do
        @api_key = "test-api-key"
        @base_url = "https://api.openai.com/v1"
        @client = LLMClient.new(api_key: @api_key, base_url: @base_url)
      end

      test "initializes with required parameters" do
        assert_equal @api_key, @client.api_key
        assert_equal @base_url, @client.base_url
        assert_instance_of ToolRegistry, @client.tool_registry
      end

      test "raises error when API key is missing" do
        assert_raises(ArgumentError) do
          LLMClient.new(api_key: nil)
        end
      end

      test "makes successful chat completion request" do
        response_body = {
          "id" => "chatcmpl-123",
          "object" => "chat.completion",
          "created" => 1677652288,
          "model" => "gpt-4-turbo-preview",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "Hello! How can I help you?"
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => {
            "prompt_tokens" => 9,
            "completion_tokens" => 7,
            "total_tokens" => 16
          }
        }.to_json

        stub_request(:post, "#{@base_url}/chat/completions")
          .with(
            body: hash_including("model", "messages"),
            headers: { "Authorization" => "Bearer #{@api_key}" }
          )
          .to_return(status: 200, body: response_body)

        messages = [{ role: "user", content: "Hello" }]
        response = @client.chat_completion(messages)

        assert_instance_of LLMResponse, response
        assert_equal "Hello! How can I help you?", response.content
        assert_equal "assistant", response.role
        assert_equal 16, response.total_tokens
      end

      test "handles tool calling in response" do
        response_body = {
          "id" => "chatcmpl-123",
          "choices" => [
            {
              "message" => {
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_123",
                    "type" => "function",
                    "function" => {
                      "name" => "get_weather",
                      "arguments" => '{"location": "San Francisco"}'
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ]
        }.to_json

        stub_request(:post, "#{@base_url}/chat/completions")
          .to_return(status: 200, body: response_body)

        messages = [{ role: "user", content: "What's the weather?" }]
        response = @client.chat_completion(messages)

        assert response.has_tool_calls?
        assert_equal 1, response.tool_calls.length
        assert_equal "get_weather", response.tool_calls.first[:function][:name]
      end

      test "retries on rate limit error" do
        stub_request(:post, "#{@base_url}/chat/completions")
          .to_return(status: 429, body: "Rate limited")
          .then
          .to_return(status: 200, body: { "choices" => [{ "message" => { "content" => "Success" } }] }.to_json)

        messages = [{ role: "user", content: "Test" }]
        response = @client.chat_completion(messages)

        assert_equal "Success", response.content
      end

      test "handles streaming responses" do
        chunks = [
          'data: {"choices":[{"delta":{"content":"Hello"}}]}',
          'data: {"choices":[{"delta":{"content":" world"}}]}',
          'data: {"choices":[{"finish_reason":"stop"}]}',
          'data: [DONE]'
        ].join("\n\n")

        stub_request(:post, "#{@base_url}/chat/completions")
          .with(body: hash_including("stream" => true))
          .to_return(status: 200, body: chunks)

        messages = [{ role: "user", content: "Hi" }]
        collected_content = ""

        @client.chat_completion(messages, stream: true) do |chunk|
          if chunk["choices"]&.first&.dig("delta", "content")
            collected_content += chunk["choices"].first["delta"]["content"]
          end
        end

        assert_equal "Hello world", collected_content
      end

      test "executes tools and continues conversation" do
        # First response with tool call
        first_response = {
          "choices" => [{
            "message" => {
              "role" => "assistant",
              "tool_calls" => [{
                "id" => "call_1",
                "type" => "function",
                "function" => {
                  "name" => "read_file",
                  "arguments" => '{"path": "/tmp/test.txt"}'
                }
              }]
            },
            "finish_reason" => "tool_calls"
          }]
        }.to_json

        # Second response after tool execution
        second_response = {
          "choices" => [{
            "message" => {
              "role" => "assistant",
              "content" => "The file contains: test content"
            },
            "finish_reason" => "stop"
          }]
        }.to_json

        stub_request(:post, "#{@base_url}/chat/completions")
          .to_return(status: 200, body: first_response)
          .then
          .to_return(status: 200, body: second_response)

        # Mock file reading
        File.stub(:exist?, true) do
          File.stub(:directory?, false) do
            File.stub(:read, "test content") do
              messages = [{ role: "user", content: "Read /tmp/test.txt" }]
              response = @client.chat_with_tools(messages)

              assert_equal "The file contains: test content", response.content
            end
          end
        end
      end

      test "configuration loads from environment" do
        ENV["OPENAI_API_KEY"] = "env-api-key"
        ENV["OPENAI_BASE_URL"] = "https://custom.api.com/v1"
        ENV["OPENAI_MODEL"] = "custom-model"

        config = Configuration.new
        assert_equal "env-api-key", config.api_key
        assert_equal "https://custom.api.com/v1", config.base_url
        assert_equal "custom-model", config.model
      ensure
        ENV.delete("OPENAI_API_KEY")
        ENV.delete("OPENAI_BASE_URL")
        ENV.delete("OPENAI_MODEL")
      end

      test "tool registry registers and executes custom tools" do
        registry = ToolRegistry.new
        
        executed = false
        registry.register(
          name: "custom_tool",
          description: "A custom tool",
          parameters: { "type" => "object", "properties" => {} }
        ) do |_args|
          executed = true
          "Tool executed"
        end

        result = registry.execute("custom_tool", {})
        assert executed
        assert_equal "Tool executed", result
      end

      test "session manager tracks conversation history" do
        session = SessionManager.new
        
        session.add_system_message("You are helpful")
        session.add_user_message("Hello")
        session.add_assistant_message("Hi there!")
        
        messages = session.get_messages
        assert_equal 3, messages.length
        assert_equal "system", messages[0][:role]
        assert_equal "user", messages[1][:role]
        assert_equal "assistant", messages[2][:role]
      end

      test "session manager exports and imports conversations" do
        session = SessionManager.new
        session.add_user_message("Test message")
        session.add_assistant_message("Test response")
        
        # Export and reimport
        json_export = session.export(format: :json)
        
        new_session = SessionManager.new
        new_session.import(json_export, format: :json)
        
        messages = new_session.get_messages
        assert_equal 2, messages.length
        assert_equal "Test message", messages[0][:content]
        assert_equal "Test response", messages[1][:content]
      end

      test "stream accumulator handles partial tool calls" do
        accumulator = LLMResponse::StreamAccumulator.new
        
        # First chunk with tool call start
        accumulator.add_chunk({
          "choices" => [{
            "delta" => {
              "tool_calls" => [{
                "index" => 0,
                "id" => "call_1",
                "type" => "function",
                "function" => { "name" => "get_time", "arguments" => "{\"time" }
              }]
            }
          }]
        })
        
        refute accumulator.complete_tool_call?
        
        # Second chunk completing arguments
        accumulator.add_chunk({
          "choices" => [{
            "delta" => {
              "tool_calls" => [{
                "index" => 0,
                "function" => { "arguments" => "zone\": \"UTC\"}" }
              }]
            }
          }]
        })
        
        assert accumulator.complete_tool_call?
        tool_call = accumulator.get_tool_call
        assert_equal "get_time", tool_call[:function][:name]
        assert_equal '{"timezone": "UTC"}', tool_call[:function][:arguments]
      end
    end
  end
end