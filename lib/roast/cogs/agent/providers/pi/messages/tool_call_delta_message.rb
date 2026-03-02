# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolCallDeltaMessage < Message
              IGNORED_FIELDS = [
                :assistantMessageEvent,
              ].freeze

              #: String
              attr_reader :delta

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                event = hash.dig(:assistantMessageEvent) || {}
                @delta = event[:delta] || ""
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end
            end
          end
        end
      end
    end
  end
end
