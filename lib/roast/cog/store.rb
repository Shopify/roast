# typed: true
# frozen_string_literal: true

module Roast
  class Cog
    class Store
      class CogAlreadyDefinedError < Roast::Error; end

      delegate :[], :key?, to: :store

      #: Hash[Symbol, Cog]
      attr_reader :store

      #: () -> void
      def initialize
        @store = {}
      end

      #: (Cog) -> Roast::Cog
      def insert(cog)
        raise CogAlreadyDefinedError, cog.name if store.key?(cog.name)

        store[cog.name] = cog
      end
    end
  end
end
