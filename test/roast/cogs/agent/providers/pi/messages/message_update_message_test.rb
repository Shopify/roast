# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class MessageUpdateMessageTest < ActiveSupport::TestCase
              test "initialize extracts assistantMessageEvent" do
                hash = {
                  assistantMessageEvent: { type: "text_delta", delta: "Hello" },
                  message: { role: "assistant" },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "text_delta", message.assistant_message_event[:type]
              end

              test "initialize extracts message" do
                hash = {
                  assistantMessageEvent: { type: "text_delta" },
                  message: { role: "assistant", model: "claude-opus-4-6" },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "assistant", message.message[:role]
              end

              test "initialize removes parsed fields from hash" do
                hash = {
                  assistantMessageEvent: { type: "text_delta" },
                  message: { role: "assistant" },
                }
                MessageUpdateMessage.new(type: "message_update", hash:)

                refute hash.key?(:assistantMessageEvent)
                refute hash.key?(:message)
              end

              test "event_type returns type from assistant_message_event" do
                hash = { assistantMessageEvent: { type: "text_delta" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "text_delta", message.event_type
              end

              test "event_type returns nil when no event" do
                message = MessageUpdateMessage.new(type: "message_update", hash: {})

                assert_nil message.event_type
              end

              test "delta returns delta from assistant_message_event" do
                hash = { assistantMessageEvent: { type: "text_delta", delta: "Hello world" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "Hello world", message.delta
              end

              test "delta returns nil for non-delta events" do
                hash = { assistantMessageEvent: { type: "text_start" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_nil message.delta
              end

              test "content_index returns contentIndex" do
                hash = { assistantMessageEvent: { type: "text_delta", contentIndex: 0 } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal 0, message.content_index
              end

              test "tool_call returns toolCall from toolcall_end event" do
                hash = {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { type: "toolCall", name: "read", arguments: { path: "/tmp/test.txt" } },
                  },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "read", message.tool_call[:name]
                assert_equal "/tmp/test.txt", message.tool_call[:arguments][:path]
              end

              test "content returns content from text_end event" do
                hash = {
                  assistantMessageEvent: { type: "text_end", content: "Full text" },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "Full text", message.content
              end

              # format tests

              test "format returns delta for text_delta events" do
                hash = { assistantMessageEvent: { type: "text_delta", delta: "Hello" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "Hello", message.format
              end

              test "format returns tool info for toolcall_end events" do
                hash = {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { name: "bash", arguments: { command: "ls" } },
                  },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                result = message.format
                assert_equal "BASH: ls", result
              end

              test "format returns ToolUse formatted output for read tool" do
                hash = {
                  assistantMessageEvent: {
                    type: "toolcall_end",
                    toolCall: { name: "read", arguments: { path: "/tmp/test.txt" } },
                  },
                }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_equal "READ: /tmp/test.txt", message.format
              end

              test "format returns nil for text_start events" do
                hash = { assistantMessageEvent: { type: "text_start" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_nil message.format
              end

              test "format returns nil for text_end events" do
                hash = { assistantMessageEvent: { type: "text_end", content: "done" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_nil message.format
              end

              test "format returns nil for toolcall_start events" do
                hash = { assistantMessageEvent: { type: "toolcall_start" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_nil message.format
              end

              test "format returns nil for toolcall_delta events" do
                hash = { assistantMessageEvent: { type: "toolcall_delta", delta: "{" } }
                message = MessageUpdateMessage.new(type: "message_update", hash:)

                assert_nil message.format
              end

              test "format returns nil when no event" do
                message = MessageUpdateMessage.new(type: "message_update", hash: {})

                assert_nil message.format
              end
            end
          end
        end
      end
    end
  end
end
