# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ThinkingStartMessage < Message
              IGNORED_FIELDS = [
                :assistantMessageEvent,
              ].freeze

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
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
