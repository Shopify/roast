# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class MessageEndMessageTest < ActiveSupport::TestCase
              test "initialize extracts message" do
                hash = { message: { role: "assistant", content: [] } }
                message = MessageEndMessage.new(type: "message_end", hash:)

                assert_equal "assistant", message.message[:role]
              end

              test "initialize removes message from hash" do
                hash = { message: { role: "user" } }
                MessageEndMessage.new(type: "message_end", hash:)

                refute hash.key?(:message)
              end

              test "role returns role from message" do
                hash = { message: { role: "user" } }
                message = MessageEndMessage.new(type: "message_end", hash:)

                assert_equal "user", message.role
              end

              test "role returns nil when message is nil" do
                message = MessageEndMessage.new(type: "message_end", hash: {})

                assert_nil message.role
              end

              test "model returns model from assistant message" do
                hash = { message: { role: "assistant", model: "claude-opus-4-6" } }
                message = MessageEndMessage.new(type: "message_end", hash:)

                assert_equal "claude-opus-4-6", message.model
              end

              test "usage returns usage from assistant message" do
                hash = {
                  message: {
                    role: "assistant",
                    usage: { input: 3, output: 5, cost: { total: 0.028 } },
                  },
                }
                message = MessageEndMessage.new(type: "message_end", hash:)

                assert_equal 3, message.usage[:input]
                assert_equal 5, message.usage[:output]
              end

              test "usage returns nil when message is nil" do
                message = MessageEndMessage.new(type: "message_end", hash: {})

                assert_nil message.usage
              end

              test "content returns content array" do
                hash = {
                  message: {
                    content: [{ type: "text", text: "Hello" }],
                  },
                }
                message = MessageEndMessage.new(type: "message_end", hash:)

                assert_equal 1, message.content.length
                assert_equal "Hello", message.content.first[:text]
              end

              test "content returns empty array when message is nil" do
                message = MessageEndMessage.new(type: "message_end", hash: {})

                assert_equal [], message.content
              end
            end
          end
        end
      end
    end
  end
end
