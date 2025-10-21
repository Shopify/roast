# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Map < SystemCog
        class Params < SystemCog::Params
          #: Symbol
          attr_accessor :scope

          #: (Symbol, ?Symbol?) -> void
          def initialize(scope, name = nil)
            super(name)
            @scope = scope
          end
        end

        class Input < Cog::Input
          #: Array[untyped]
          attr_accessor :items

          def initialize
            super
            @items = []
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'items' is required" if items.nil?
            # raise a validation error items is empty and coercion has not been run, to allow coercion to proceed
            raise Cog::Input::InvalidInputError if items.blank? && !permit_empty_items?
          end

          #: (Array[untyped]) -> void
          def coerce(input_return_value)
            @items = Array.wrap(input_return_value) unless @items.present?
          end

          private

          #: () -> bool
          def permit_empty_items?
            @permit_empty_items ||= false
          end
        end

        # @requires_ancestor: ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Map
          def create_map_system_cog(params, input_proc)
            SystemCogs::Map.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.scope.present?

              # For now, just process each item sequentially in a single thread
              input.items.each do |item|
                em = ExecutionManager.new(
                  @cog_registry,
                  @config_manager,
                  @all_execution_procs,
                  params.scope,
                  item,
                )
                em.prepare!
                em.run!
              end

              Cog::Output.new
            end
          end
        end
      end
    end
  end
end
