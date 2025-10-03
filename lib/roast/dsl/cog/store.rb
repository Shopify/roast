# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Store
        class CogAlreadyDefinedError < Roast::Error; end

        #: (Symbol) -> Roast::DSL::Cog?
        def find(id)
          store[id]
        end

        #: (Symbol, Roast::DSL::Cog) -> Roast::DSL::Cog
        def insert(id, inst)
          raise CogAlreadyDefinedError if store.key?(id)

          store[id] = inst
        end

        #: () -> Hash[Symbol, Roast::DSL::Cog]
        def store
          @store ||= {}
        end
      end
    end
  end
end
