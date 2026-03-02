# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class TextDeltaMessageTest < ActiveSupport::TestCase
              test "extracts delta from assistantMessageEvent" do
                message = TextDeltaMessage.new(
                  type: :text_delta,
                  hash: {
                    assistantMessageEvent: { type: "text_delta", delta: "Hello world", contentIndex: 0, partial: {} },
                    message: {},
                  },
                )

                assert_equal "Hello world", message.delta
              end

              test "format returns the delta text" do
                message = TextDeltaMessage.new(
                  type: :text_delta,
                  hash: {
                    assistantMessageEvent: { type: "text_delta", delta: "chunk", contentIndex: 0, partial: {} },
                    message: {},
                  },
                )

                context = PiInvocation::Context.new
                assert_equal "chunk", message.format(context)
              end

              test "delta defaults to empty string when missing" do
                message = TextDeltaMessage.new(
                  type: :text_delta,
                  hash: { assistantMessageEvent: { type: "text_delta" } },
                )

                assert_equal "", message.delta
              end
            end
          end
        end
      end
    end
  end
end
