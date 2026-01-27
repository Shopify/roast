# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class UserMessageTest < ActiveSupport::TestCase
              test "initialize with empty message content" do
                hash = { message: { content: [] } }
                message = UserMessage.new(type: :user, hash:)

                assert_equal [], message.messages
              end

              test "initialize with nil message" do
                hash = {}
                message = UserMessage.new(type: :user, hash:)

                assert_equal [], message.messages
              end

              test "initialize with message content creates messages" do
                hash = {
                  message: {
                    content: [
                      { type: :text, text: "Hello" },
                      { type: :text, text: "World" },
                    ],
                  },
                }
                message = UserMessage.new(type: :user, hash:)

                assert_equal 2, message.messages.length
              end

              test "initialize sets role to user on content items" do
                hash = {
                  message: {
                    content: [
                      { type: :text, text: "Hello" },
                    ],
                  },
                }
                message = UserMessage.new(type: :user, hash:)

                assert_equal :user, message.messages.first.role
              end

              test "initialize removes message from hash" do
                hash = { message: { content: [] } }
                UserMessage.new(type: :user, hash:)

                refute hash.key?(:message)
              end

              test "initialize removes parent_tool_use_id from hash" do
                hash = { parent_tool_use_id: "123" }
                UserMessage.new(type: :user, hash:)

                refute hash.key?(:parent_tool_use_id)
              end

              test "initialize removes tool_use_result from hash" do
                hash = { tool_use_result: "result" }
                UserMessage.new(type: :user, hash:)

                refute hash.key?(:tool_use_result)
              end

              test "initialize handles message content without nils" do
                hash = {
                  message: {
                    content: [
                      { type: :text, text: "Hello" },
                      { type: :text, text: "World" },
                    ],
                  },
                }
                message = UserMessage.new(type: :user, hash:)

                assert_equal 2, message.messages.length
                assert_equal "Hello", message.messages.first.text
                assert_equal "World", message.messages.last.text
              end
            end
          end
        end
      end
    end
  end
end
