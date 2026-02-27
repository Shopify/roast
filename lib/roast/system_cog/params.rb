# typed: true
# frozen_string_literal: true

module Roast
  class SystemCog
    # Parameters for system cogs set at workflow evaluation time
    #
    # Params are used to provide limited evaluation-time parameterization to system cogs,
    # such as the name of the execute scope to be invoked by a `call`, `map`, a, `repeat` cog.
    #
    # System cogs also accept input at execution time, just like regular cogs.
    class Params
      # The name identifier for this system cog instance
      #
      # Used to reference this cog's output. Auto-generated if not provided.
      #
      #: Symbol
      attr_reader :name

      # Initialize parameters with the cog name
      #
      # Subclasses should define their own `initialize` accepting specific parameters.
      #
      #: (Symbol?) -> void
      def initialize(name)
        @anonymous = name.nil? #: bool
        @name = name || Cog.generate_fallback_name
      end

      # Whether the cog is using a fallback name, or was given one explicitly.
      #
      #: () -> bool
      def anonymous?
        @anonymous
      end
    end
  end
end
