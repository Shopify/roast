# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Catch-all for unrecognized Pi message types
            class UnknownMessage < Message
              #: Hash[Symbol, untyped]
              attr_reader :raw

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
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
