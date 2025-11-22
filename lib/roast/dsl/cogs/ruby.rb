# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Ruby < Cog
        class Config < Cog::Config; end

        # Input specification for the ruby cog
        #
        # The ruby cog accepts any Ruby value from the input block, which will be directly
        # passed through to the output without modification.
        class Input < Cog::Input
          # The value to pass through to the output
          #
          # This value will be directly returned as the `value` attribute on the cog's output object.
          #
          #: untyped
          attr_accessor :value

          # Validate that the input has all required parameters
          #
          # This method ensures that a value has been provided, either directly via the `value`
          # attribute or through the input block (via `coerce`).
          #
          # #### See Also
          # - `coerce`
          #
          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError if value.nil? && !coerce_ran?
          end

          # Coerce the input from the return value of the input block
          #
          # The return value from the input block will be used directly as the `value` attribute.
          # This allows any Ruby object to be passed through the ruby cog.
          #
          # #### See Also
          # - `validate!`
          #
          #: (untyped) -> void
          def coerce(input_return_value)
            super
            @value = input_return_value
          end
        end

        # Output from running the ruby cog
        #
        # Contains the value that was provided to the input block, passed through unchanged.
        # This allows Ruby values to be used directly in workflow steps.
        class Output < Cog::Output
          # The value passed through from the input
          #
          #: untyped
          attr_reader :value

          #: (untyped) -> void
          def initialize(value)
            super()
            @value = value
          end
        end

        #: (Input) -> Output
        def execute(input)
          Output.new(input.value)
        end
      end
    end
  end
end
