# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the beginning of a user or assistant message
            #
            # Example:
            #   {"type":"message_start","message":{"role":"user","content":[...]}}
            #   {"type":"message_start","message":{"role":"assistant","content":[],"model":"..."}}
            class MessageStartMessage < Message
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
            end
          end
        end
      end
    end
  end
end
