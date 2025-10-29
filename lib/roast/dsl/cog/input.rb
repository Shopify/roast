# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Abstract parent class for inputs provided to a cog when it runs.
      # Cogs should extend this class with their own input types
      # Input classes should be instantiatable with a no-arg constructor,
      # and expose methods to incrementally set their values.
      class Input
        class InputError < Roast::Error; end
        class InvalidInputError < InputError; end

        # Validate that the input instance has all required parameters set in an acceptable manner.
        # Inheriting cog must implement this for its input class.
        #: () -> void
        def validate!
          raise NotImplementedError
        end

        # Use the value returned from the cog's input block to attempt to coerce the input to a valid state.
        # to coerce the input to a valid state.
        # Inheriting cog may implement this for its input class; it is optional
        #: (untyped) -> void
        def coerce(input_return_value)
          @coerce_ran = true
        end

        private

        #: () -> bool
        def coerce_ran?
          @coerce_ran ||= false
        end
      end
    end
  end
end
