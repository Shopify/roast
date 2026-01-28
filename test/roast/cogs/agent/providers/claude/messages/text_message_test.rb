# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class TextMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { role: :user, text: "Hello world" }
                @message = TextMessage.new(type: :text, hash: @hash.dup)
              end

              test "initialize sets role from hash" do
                assert_equal :user, @message.role
              end

              test "initialize sets text from hash" do
                assert_equal "Hello world", @message.text
              end

              test "initialize removes role from hash" do
                hash = { role: :assistant, text: "test" }
                TextMessage.new(type: :text, hash:)

                refute hash.key?(:role)
              end

              test "initialize removes text from hash" do
                hash = { text: "test" }
                TextMessage.new(type: :text, hash:)

                refute hash.key?(:text)
              end

              test "initialize sets text to empty string when nil" do
                hash = { role: :user }
                message = TextMessage.new(type: :text, hash:)

                assert_equal "", message.text
              end

              test "initialize sets text to empty string when not provided" do
                hash = { role: :user, text: nil }
                message = TextMessage.new(type: :text, hash:)

                assert_equal "", message.text
              end

              test "format returns text" do
                context = Object.new
                result = @message.format(context)

                assert_equal "Hello world", result
              end

              test "format returns text regardless of context" do
                result = @message.format(nil)

                assert_equal "Hello world", result
              end
            end
          end
        end
      end
    end
  end
end
