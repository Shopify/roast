# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        # Abstract parent class for implementations of a Provider for the Agent cog
        class Provider
          #: (Config) -> void
          def initialize(config)
            super()
            @config = config
          end

          #: (Input) -> Output
          def invoke(input)
            raise NotImplementedError, "Subclasses must implement #invoke"
          end
        end
      end
    end
  end
end
