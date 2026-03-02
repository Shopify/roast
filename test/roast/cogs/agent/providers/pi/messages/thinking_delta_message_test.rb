# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ThinkingDeltaMessageTest < ActiveSupport::TestCase
              test "extracts delta from assistantMessageEvent" do
                message = ThinkingDeltaMessage.new(
                  type: :thinking_delta,
                  hash: {
                    assistantMessageEvent: { type: "thinking_delta", delta: "Let me consider...", contentIndex: 0, partial: {} },
                    message: {},
                  },
                )

                assert_equal "Let me consider...", message.delta
              end

              test "format returns the thinking delta" do
                message = ThinkingDeltaMessage.new(
                  type: :thinking_delta,
                  hash: {
                    assistantMessageEvent: { type: "thinking_delta", delta: "hmm", contentIndex: 0, partial: {} },
                    message: {},
                  },
                )

                context = PiInvocation::Context.new
                assert_equal "hmm", message.format(context)
              end
            end
          end
        end
      end
    end
  end
end
