#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

# Example usage of the Roast TUI LLM Client with OpenAI API
# This demonstrates all the key features:
# - Basic chat completion
# - Streaming responses
# - Tool/function calling
# - Parallel tool execution
# - Custom tool registration
# - Error handling and retries

require_relative "llm_client"
require_relative "llm_response"
require_relative "tool_registry"
require "cli/ui"

module Roast
  module TUI
    class Example
      def self.run
        new.demonstrate_all_features
      end

      def initialize
        @client = create_client
      end

      def demonstrate_all_features
        CLI::UI::Frame.open("Roast TUI LLM Client Demo") do
          demo_basic_completion
          demo_streaming_completion
          demo_tool_calling
          demo_parallel_tools
          demo_streaming_with_tools
          demo_custom_tools
        end
      end

      private

      def create_client
        # Create a client with custom tools
        registry = ToolRegistry.new
        
        # Add a custom tool for the demo
        registry.register(
          name: "get_current_time",
          description: "Get the current time in a specific timezone",
          parameters: {
            type: "object",
            properties: {
              timezone: {
                type: "string",
                description: "The timezone (e.g., 'America/New_York', 'Europe/London')"
              }
            },
            required: ["timezone"]
          }
        ) do |args|
          require "time"
          ENV["TZ"] = args["timezone"]
          Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
        end

        LLMClient.new(tool_registry: registry)
      end

      def demo_basic_completion
        CLI::UI::Frame.open("Basic Chat Completion") do
          messages = [
            { role: "system", content: "You are a helpful assistant." },
            { role: "user", content: "What is Ruby on Rails?" }
          ]

          response = @client.chat_completion(messages)
          
          CLI::UI.puts("Response: #{response.content}")
          CLI::UI.puts("Tokens used: #{response.total_tokens}")
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end

      def demo_streaming_completion
        CLI::UI::Frame.open("Streaming Chat Completion") do
          messages = [
            { role: "user", content: "Write a haiku about Ruby programming." }
          ]

          CLI::UI::Spinner.spin("Streaming response") do |spinner|
            content = ""
            
            @client.chat_completion(messages, stream: true) do |chunk|
              if chunk["choices"]&.first&.dig("delta", "content")
                new_content = chunk["choices"].first["delta"]["content"]
                content += new_content
                spinner.update_title("Streaming: #{content.split("\n").last}")
              end
            end
            
            spinner.update_title("Complete!")
            CLI::UI.puts("\n#{content}")
          end
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end

      def demo_tool_calling
        CLI::UI::Frame.open("Tool Calling Example") do
          messages = [
            { role: "user", content: "What time is it in Tokyo and London?" }
          ]

          CLI::UI::Progress.progress do |bar|
            response = @client.chat_with_tools(messages) do |event|
              case event[:type]
              when :tool_start
                bar.tick(set_percent: 0.33)
                CLI::UI.puts("{{cyan:→}} Calling tool: #{event[:name]}")
              when :tool_complete
                bar.tick(set_percent: 0.66)
                CLI::UI.puts("{{green:✓}} Tool result: #{event[:result]}")
              end
            end
            
            bar.tick(set_percent: 1.0)
            CLI::UI.puts("\n{{bold:Final response:}}")
            CLI::UI.puts(response.content)
          end
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end

      def demo_parallel_tools
        CLI::UI::Frame.open("Parallel Tool Execution") do
          messages = [
            { 
              role: "user", 
              content: "List the files in /tmp, read /etc/hosts if it exists, and tell me the current time in UTC."
            }
          ]

          start_time = Time.now
          
          response = @client.chat_with_tools(messages) do |event|
            case event[:type]
            when :tool_start
              CLI::UI.puts("{{cyan:→}} [#{Time.now - start_time}s] Starting: #{event[:name]}")
            when :tool_complete
              CLI::UI.puts("{{green:✓}} [#{Time.now - start_time}s] Completed: #{event[:name]}")
            end
          end
          
          CLI::UI.puts("\n{{bold:Response:}} #{response.content}")
          CLI::UI.puts("{{yellow:Total time: #{Time.now - start_time}s}}")
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end

      def demo_streaming_with_tools
        CLI::UI::Frame.open("Streaming with Tool Calls") do
          messages = [
            { 
              role: "user", 
              content: "What's the weather file at /tmp/weather.txt say? If it doesn't exist, create it with 'Sunny, 72°F'."
            }
          ]

          CLI::UI::StdoutRouter.with_frame_inset(prefix: "LLM: ") do
            @client.stream_with_tools(messages) do |event|
              case event[:type]
              when :chunk
                # Content chunks are displayed as they arrive
                if event[:data]["choices"]&.first&.dig("delta", "content")
                  print event[:data]["choices"].first["delta"]["content"]
                end
              when :tool_start
                puts "\n{{cyan:→ Calling #{event[:name]}}}"
              when :tool_result
                puts "{{green:✓ Tool completed}}"
              end
            end
          end
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end

      def demo_custom_tools
        CLI::UI::Frame.open("Custom Tool Registration") do
          # Create a minimal registry for this demo
          custom_registry = ToolRegistry.create_minimal
          
          # Register a calculation tool
          custom_registry.register(
            name: "calculate",
            description: "Perform mathematical calculations",
            parameters: {
              type: "object",
              properties: {
                expression: {
                  type: "string",
                  description: "The mathematical expression to evaluate"
                }
              },
              required: ["expression"]
            }
          ) do |args|
            # In production, use a safe math parser
            result = eval(args["expression"])
            "The result of #{args["expression"]} is #{result}"
          end
          
          # Create client with custom registry
          custom_client = LLMClient.new(tool_registry: custom_registry)
          
          messages = [
            { role: "user", content: "What is 42 * 17 + 3?" }
          ]
          
          response = custom_client.chat_with_tools(messages) do |event|
            if event[:type] == :tool_start
              CLI::UI.puts("{{cyan:Calculating:}} #{event[:arguments]["expression"]}")
            end
          end
          
          CLI::UI.puts("{{bold:Answer:}} #{response.content}")
        end
      rescue => e
        CLI::UI.puts("{{red:Error: #{e.message}}}")
      end
    end
  end
end

# Run the example if executed directly
if __FILE__ == $0
  Roast::TUI::Example.run
end