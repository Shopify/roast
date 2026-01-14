# typed: true
# frozen_string_literal: true

module Roast
  class Cog
    # Abstract parent class for inputs provided to a cog when it runs
    #
    # Cogs extend this class to define their own input types that specify what data the cog needs to execute.
    # Input classes must be instantiatable with a no-argument constructor and expose methods to incrementally
    # set their values.
    #
    # The input lifecycle:
    # 1. An input instance is created when the cog is invoked
    # 2. The `validate!` method is called to see if all required parameters are set correctly (errors are swallowed)
    # 3. If validation fails, the `coerce` method is called with the return value from the input block (if provided)
    # 4. The `validate!` method is called again to ensure all required parameters are set correctly (errors are raised)
    # 4. The validated input is passed to the cog's `execute` method
    class Input
      # Parent class for all errors raised by the Roast::Input class
      class InputError < Roast::Error; end

      # Raised when validation fails on a cog's input object.
      class InvalidInputError < InputError; end

      # Validate that the input instance has all required parameters set in an acceptable manner
      #
      # Subclasses must implement this method to verify that the input is in a valid state before
      # the cog executes. This method should raise an `InvalidInputError` if the input is not valid.
      #
      # #### See Also
      # - `coerce`
      #
      #: () -> void
      def validate!
        raise NotImplementedError
      end

      # Use the value returned from the cog's input block to coerce the input to a valid state
      #
      # Subclasses may implement this method to automatically configure the input based on the return
      # value from the input block. This is optional; if not implemented, the default behavior is to
      # do nothing.
      #
      # #### See Also
      # - `validate!`
      #
      #: (untyped) -> void
      def coerce(input_return_value)
        @coerce_ran = true
      end

      private

      # Determine whether the input's coerce method has already been attempted
      #
      # This can be useful for validate! to adapt its behaviour based on whether it is being called the first
      # or second time.
      #
      # For instance, if an input has an attribute than can legitimately be `nil`, but the cog
      # still wants to attempt coercion if the attribute is not set to a non-`nil` value initially, `validate!`
      # can be implemented to raise `InvalidInputError` if the attribute is `nil` and `coerce_ran?` is `false`,
      # but not to raise if `coerce_ran?` is `true`, to allow the input to be ultimately validated with a `nil`
      # value for that attribute.
      #
      #: () -> bool
      def coerce_ran?
        @coerce_ran ||= false
      end
    end
  end
end
