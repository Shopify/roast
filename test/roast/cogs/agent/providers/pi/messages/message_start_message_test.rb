# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class MessageStartMessageTest < ActiveSupport::TestCase
              test "initialize extracts message" do
                hash = { message: { role: "user", content: [] } }
                message = MessageStartMessage.new(type: "message_start", hash:)

                assert_equal "user", message.message[:role]
              end

              test "initialize removes message from hash" do
                hash = { message: { role: "user" } }
                MessageStartMessage.new(type: "message_start", hash:)

                refute hash.key?(:message)
              end

              test "role returns role from message" do
                hash = { message: { role: "assistant" } }
                message = MessageStartMessage.new(type: "message_start", hash:)

                assert_equal "assistant", message.role
              end

              test "role returns nil when message is nil" do
                message = MessageStartMessage.new(type: "message_start", hash: {})

                assert_nil message.role
              end

              test "model returns model from message" do
                hash = { message: { role: "assistant", model: "claude-opus-4-6" } }
                message = MessageStartMessage.new(type: "message_start", hash:)

                assert_equal "claude-opus-4-6", message.model
              end

              test "model returns nil for user messages" do
                hash = { message: { role: "user" } }
                message = MessageStartMessage.new(type: "message_start", hash:)

                assert_nil message.model
              end
            end
          end
        end
      end
    end
  end
end
