# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Base
            #: (String) -> String
            def invoke(prompt)
              raise NotImplementedError, "Subclasses must implement #invoke"
            end
          end
        end
      end
    end
  end
end
