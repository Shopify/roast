# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      module Updatable
        include Kernel

        #: (Roast::DSL::Cog) -> void
        def update(other)
          raise NotImplementedError, "Must implement update() in order to be updatable."
        end
      end
    end
  end
end
