# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Execute < Cog
        class Input < Cog::Input
          #: Symbol?
          attr_accessor :scope

          #: untyped
          attr_accessor :value

          #: () -> void
          def initialize
            super
            @scope = nil
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'scope' is required" unless scope.present?
          end

          #: (Symbol | Array[untyped]) -> void
          def coerce(input_return_value)
            case input_return_value
            when Symbol
              self.scope = input_return_value
            when Array
              return if input_return_value.empty?

              self.scope = input_return_value.first.to_sym
              self.value = input_return_value.second
              # TODO: log a warning if there are more than two elements in the array
            end
          end
        end

        #: (Symbol, ^(Input) -> untyped, ^(Input) -> void) -> void
        def initialize(name, cog_input_proc, trigger)
          # NOTE: Sorbet expects the proc passed to super to be declared as taking a Cog::Input explicitly,
          # not a subclass of Cog::Input.
          cog_input_proc = cog_input_proc #: as ^(Cog::Input) -> untyped
          super(name, cog_input_proc)
          @trigger = trigger
        end

        #: (Input) -> Cog::Output
        def execute(input)
          @trigger.call(input)
          Cog::Output.new
        end
      end
    end
  end
end
