# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Map < SystemCog
        class Input < Cog::Input
          #: Array[untyped]
          attr_accessor :items

          def initialize
            @items = []
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'items' is required" unless items.present?
          end

          #: (Array[untyped]) -> void
          def coerce(input_return_value)
            case input_return_value
            when Array
              self.items = input_return_value
            end
          end
        end

        class Params < SystemCog::Params
          #: Symbol
          attr_accessor :map_executor_scope

          #: (Symbol, ?Symbol?) -> void
          def initialize(name, map_executor_scope = nil)
            @map_executor_scope = map_executor_scope || name
          end
        end
      end
    end
  end
end
