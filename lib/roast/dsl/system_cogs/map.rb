# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Map < SystemCog
        class Params < SystemCog::Params
          #: Symbol
          attr_accessor :run

          #: (?Symbol?, run: Symbol) -> void
          def initialize(name = nil, run:)
            super(name)
            @run = run
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

        class Output < Cog::Output
          #: (Array[ExecutionManager]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
          end
        end

        # @requires_ancestor: ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Map
          def create_map_system_cog(params, input_proc)
            SystemCogs::Map.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              # For now, just process each item sequentially in a single thread
              ems = input.items.map do |item|
                em = ExecutionManager.new(
                  @cog_registry,
                  @config_manager,
                  @all_execution_procs,
                  params.run,
                  item,
                )
                em.prepare!
                em.run!
                em
              end

              Output.new(ems)
            end
          end
        end

        # @requires_ancestor: CogInputContext
        module InputContext
          #: [T] (Roast::DSL::SystemCogs::Map::Output) {() -> T} -> Array[T]
          def collect(map_cog_output, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            ems.map { |em| em.cog_input_context.instance_exec(&block) unless em.nil? }
          end
        end
      end
    end
  end
end
