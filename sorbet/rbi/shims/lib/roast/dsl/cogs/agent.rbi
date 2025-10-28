# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent
        class Config
          #: (Symbol) -> Symbol
          #: () -> Symbol
          def provider(value); end

          #: () -> Symbol
          def use_default_provider!; end
        end
      end
    end
  end
end
