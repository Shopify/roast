# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class LLMResponse
      attr_reader :raw_response, :message, :usage, :finish_reason

      def initialize(raw_response)
        @raw_response = raw_response
        parse_response
      end

      def content
        @message[:content]
      end

      def role
        @message[:role]
      end

      def tool_calls
        @message[:tool_calls] || []
      end

      def has_tool_calls?
        !tool_calls.empty?
      end

      def to_message
        @message.dup
      end

      def total_tokens
        @usage[:total_tokens] if @usage
      end

      def prompt_tokens
        @usage[:prompt_tokens] if @usage
      end

      def completion_tokens
        @usage[:completion_tokens] if @usage
      end

      def complete?
        @finish_reason != nil
      end

      def stop_reason
        @finish_reason
      end

      private

      def parse_response
        choice = @raw_response["choices"]&.first || {}
        
        @message = build_message(choice["message"] || {})
        @usage = @raw_response["usage"]
        @finish_reason = choice["finish_reason"]
      end

      def build_message(msg)
        message = {
          role: msg["role"] || "assistant",
          content: msg["content"]
        }

        if msg["tool_calls"]
          message[:tool_calls] = msg["tool_calls"].map do |tc|
            {
              id: tc["id"],
              type: tc["type"],
              function: {
                name: tc["function"]["name"],
                arguments: tc["function"]["arguments"]
              }
            }
          end
        end

        message
      end

      # Accumulator for streaming responses
      class StreamAccumulator
        attr_reader :content, :tool_calls, :role, :finish_reason

        def initialize
          @content = ""
          @tool_calls = []
          @current_tool_call = nil
          @role = "assistant"
          @finish_reason = nil
        end

        def add_chunk(chunk)
          return unless chunk["choices"]&.any?
          
          choice = chunk["choices"].first
          delta = choice["delta"] || {}
          
          # Update role if provided
          @role = delta["role"] if delta["role"]
          
          # Accumulate content
          if delta["content"]
            @content += delta["content"]
          end
          
          # Handle tool calls
          if delta["tool_calls"]
            process_tool_calls(delta["tool_calls"])
          end
          
          # Update finish reason
          @finish_reason = choice["finish_reason"] if choice["finish_reason"]
        end

        def complete?
          @finish_reason != nil
        end

        def has_content?
          !@content.empty?
        end

        def has_tool_calls?
          !@tool_calls.empty?
        end

        def complete_tool_call?
          @current_tool_call && 
          @current_tool_call[:function][:arguments_complete]
        end

        def get_tool_call
          return nil unless complete_tool_call?
          
          tc = @current_tool_call.dup
          @current_tool_call = nil
          tc
        end

        def to_message
          message = {
            role: @role,
            content: @content.empty? ? nil : @content
          }
          
          if has_tool_calls?
            message[:tool_calls] = @tool_calls.map do |tc|
              {
                id: tc[:id],
                type: tc[:type],
                function: {
                  name: tc[:function][:name],
                  arguments: tc[:function][:arguments]
                }
              }
            end
          end
          
          message
        end

        def to_response
          # Create a mock response object that looks like a full response
          mock_response = {
            "choices" => [
              {
                "message" => to_message.transform_keys(&:to_s),
                "finish_reason" => @finish_reason
              }
            ]
          }
          
          LLMResponse.new(mock_response)
        end

        private

        def process_tool_calls(tool_call_deltas)
          tool_call_deltas.each do |tc_delta|
            index = tc_delta["index"]
            
            # Initialize or update tool call at index
            if tc_delta["id"]
              # New tool call
              @current_tool_call = {
                id: tc_delta["id"],
                type: tc_delta["type"] || "function",
                function: {
                  name: tc_delta["function"]["name"],
                  arguments: "",
                  arguments_complete: false
                }
              }
              @tool_calls[index] = @current_tool_call
            elsif @tool_calls[index]
              # Continue existing tool call
              @current_tool_call = @tool_calls[index]
              
              if tc_delta["function"]
                if tc_delta["function"]["name"]
                  @current_tool_call[:function][:name] = tc_delta["function"]["name"]
                end
                
                if tc_delta["function"]["arguments"]
                  @current_tool_call[:function][:arguments] += tc_delta["function"]["arguments"]
                  
                  # Check if arguments are complete (valid JSON)
                  begin
                    JSON.parse(@current_tool_call[:function][:arguments])
                    @current_tool_call[:function][:arguments_complete] = true
                  rescue JSON::ParserError
                    # Arguments not yet complete
                    @current_tool_call[:function][:arguments_complete] = false
                  end
                end
              end
            end
          end
        end
      end

      # Response wrapper for streaming with CLI-UI display
      class StreamingResponse
        attr_reader :accumulator

        def initialize(&display_block)
          @accumulator = StreamAccumulator.new
          @display_block = display_block
          @content_buffer = ""
        end

        def add_chunk(chunk)
          @accumulator.add_chunk(chunk)
          
          # Extract new content from the chunk
          if chunk["choices"]&.first&.dig("delta", "content")
            new_content = chunk["choices"].first["delta"]["content"]
            @content_buffer += new_content
            
            # Display the new content
            @display_block&.call(new_content)
          end
        end

        def finalize
          @accumulator.to_response
        end
      end
    end
  end
end