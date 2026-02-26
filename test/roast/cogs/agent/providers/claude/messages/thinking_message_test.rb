# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ThinkingMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { thinking: "Let me think about this...", signature: "abc123", role: :assistant }
                @message = ThinkingMessage.new(type: :thinking, hash: @hash.dup)
              end

              test "initialize sets thinking from hash" do
                assert_equal "Let me think about this...", @message.thinking
              end

              test "initialize removes thinking from hash" do
                hash = { thinking: "test" }
                ThinkingMessage.new(type: :thinking, hash:)

                refute hash.key?(:thinking)
              end

              test "initialize removes ignored fields from hash" do
                hash = { thinking: "test", signature: "sig", role: :assistant }
                ThinkingMessage.new(type: :thinking, hash:)

                refute hash.key?(:signature)
                refute hash.key?(:role)
              end

              test "initialize sets thinking to empty string when nil" do
                hash = { signature: "sig" }
                message = ThinkingMessage.new(type: :thinking, hash:)

                assert_equal "", message.thinking
              end

              test "initialize sets thinking to empty string when not provided" do
                hash = { thinking: nil }
                message = ThinkingMessage.new(type: :thinking, hash:)

                assert_equal "", message.thinking
              end

              test "format returns thinking" do
                context = Object.new
                result = @message.format(context)

                assert_equal "Let me think about this...", result
              end

              test "format returns thinking regardless of context" do
                result = @message.format(nil)

                assert_equal "Let me think about this...", result
              end
            end
          end
        end
      end
    end
  end
end
