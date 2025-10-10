# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Store
        class CogAlreadyDefinedError < Roast::Error; end

        delegate :[], to: :store

        #: Hash[Symbol, Cog]
        attr_reader :store

        #: () -> void
        def initialize
          @store = {}
        end

        #: (Symbol, Roast::DSL::Cog) -> Roast::DSL::Cog
        def insert(id, inst)
          raise CogAlreadyDefinedError if store.key?(id)

          store[id] = inst
        end
      end
    end
  end
end
