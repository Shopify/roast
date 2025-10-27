# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Ruby < Cog
        class Config < Cog::Config; end

        class Input < Cog::Input
          # This value will be directly returned as the 'value' attribute on the cog's output object
          #
          #: untyped
          attr_accessor :value

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError if value.nil? && !coerce_ran?
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            super
            @value = input_return_value
          end
        end

        class Output < Cog::Output
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
