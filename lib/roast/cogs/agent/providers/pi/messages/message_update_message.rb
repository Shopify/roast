# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Streaming update for an assistant message
            #
            # Contains an `assistantMessageEvent` with a sub-type indicating what kind of
            # update is being streamed:
            # - `text_start`: Beginning of a text content block
            # - `text_delta`: Incremental text content
            # - `text_end`: End of a text content block
            # - `toolcall_start`: Beginning of a tool call
            # - `toolcall_delta`: Incremental tool call arguments
            # - `toolcall_end`: End of a tool call with complete arguments
            #
            # Example:
            #   {"type":"message_update","assistantMessageEvent":{"type":"text_delta",
            #     "contentIndex":0,"delta":"Hello"},"message":{...}}
            class MessageUpdateMessage < Message
              #: Hash[Symbol, untyped]?
              attr_reader :assistant_message_event

              #: Hash[Symbol, untyped]?
              attr_reader :message

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @assistant_message_event = hash.delete(:assistantMessageEvent)
                @message = hash.delete(:message)
                super(type:, hash:)
              end

              # The sub-type of the assistant message event
              #
              # One of: text_start, text_delta, text_end, toolcall_start, toolcall_delta, toolcall_end
              #
              #: () -> String?
              def event_type
                @assistant_message_event&.dig(:type)
              end

              # The text delta content (for text_delta events)
              #
              #: () -> String?
              def delta
                @assistant_message_event&.dig(:delta)
              end

              # The content index this event applies to
              #
              #: () -> Integer?
              def content_index
                @assistant_message_event&.dig(:contentIndex)
              end

              # The complete tool call info (for toolcall_end events)
              #
              #: () -> Hash[Symbol, untyped]?
              def tool_call
                @assistant_message_event&.dig(:toolCall)
              end

              # The final text content (for text_end events)
              #
              #: () -> String?
              def content
                @assistant_message_event&.dig(:content)
              end

              # Format for progress display
              #
              #: () -> String?
              def format
                case event_type
                when "text_delta"
                  delta
                when "toolcall_end"
                  tc = tool_call
                  return nil unless tc

                  name = tc[:name]
                  args = tc[:arguments]
                  "TOOL: #{name} #{args.inspect}" if name
                end
              end
            end
          end
        end
      end
    end
  end
end
