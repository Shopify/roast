# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the end of a user or assistant message
            #
            # Contains the final state of the message including full content and usage.
            #
            # Example:
            #   {"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"4"}],
            #     "usage":{"input":3,"output":5,...}}}
            class MessageEndMessage < Message
              #: Hash[Symbol, untyped]?
              attr_reader :message

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @message = hash.delete(:message)
                super(type:, hash:)
              end

              # The role of the message (user or assistant)
              #
              #: () -> String?
              def role
                @message&.dig(:role)
              end

              # The model used (only present for assistant messages)
              #
              #: () -> String?
              def model
                @message&.dig(:model)
              end

              # The usage data (only present for assistant messages)
              #
              #: () -> Hash[Symbol, untyped]?
              def usage
                @message&.dig(:usage)
              end

              # The content array of the message
              #
              #: () -> Array[Hash[Symbol, untyped]]
              def content
                @message&.dig(:content) || []
              end
            end
          end
        end
      end
    end
  end
end
