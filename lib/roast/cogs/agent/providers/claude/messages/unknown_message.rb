# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class UnknownMessage < Message
              #: Hash[Symbol, untyped]
              attr_reader :raw

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                super(type:, hash:)
                @raw = hash
              end
            end
          end
        end
      end
    end
  end
end
