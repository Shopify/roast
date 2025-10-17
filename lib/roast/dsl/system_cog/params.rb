# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class SystemCog
      # Custom parameters allowable for system cogs only.
      # System cogs should extend this class with their own params types if needed.
      class Params
        def initialize(cog_name, *args, **kwargs)
          # Implementing classes should define the arguments they expect
          # instead of *args and **kwargs
        end
      end
    end
  end
end
