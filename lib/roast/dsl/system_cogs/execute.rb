# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Execute < SystemCog
        class Input < Cog::Input
          #: Symbol?
          attr_accessor :scope

          #: untyped
          attr_accessor :value

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
      end
    end
  end
end
