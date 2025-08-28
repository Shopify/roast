# typed: true
# frozen_string_literal: true

require_relative "store"

module Roast
  module DSL
    class Cog
      module Storable
        # abstract!
        #: () -> String
        def store_id
          raise NotImplementedError "Including class must implement store_id in order to be storable"
        end

        #: () -> Roast::DSL::Cog
        def store
          Store.insert(store_id, self) if store?
        end

        #: () -> Roast::DSL::Cog
        def find
          Store.find(store_id)
        end

        #: () -> bool
        def store?
          true # Optional override
        end
      end
    end
  end
end
