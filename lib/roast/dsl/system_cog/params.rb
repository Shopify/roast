# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class SystemCog
      # Custom parameters allowable for system cogs only.
      #
      # These parameters are set via arguments passed to the cog method, not via the cog's input block
      # This allows some aspects of system cogs' input to be set at workflow evaluation time,
      # rather workflow execution time.
      #
      # Only name is required.
      # System cogs should extend this class with their own params types if needed.
      class Params
        #: Symbol
        attr_reader :name

        #: (Symbol?) -> void
        def initialize(name)
          # Implementing classes should define an initialize method with the specific arguments they expect
          # Implementations must provide the system cog's name (if set) via params
          @name = name || Cog.generate_fallback_name
        end
      end
    end
  end
end
