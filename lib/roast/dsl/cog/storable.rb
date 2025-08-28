# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      module Storable
        include Kernel

        # abstract!
        #: () -> Symbol
        def store_id
          raise NotImplementedError, "Including class must implement store_id in order to be storable"
        end

        #: () -> Roast::DSL::Cog
        def store
          unless store?
            return self #: as Roast::DSL::Cog
          end

          Store.insert(store_id, T.cast(self, Roast::DSL::Cog))
        end

        #: () -> Roast::DSL::Cog?
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
