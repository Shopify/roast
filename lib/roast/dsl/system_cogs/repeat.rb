# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Repeat < SystemCog
        class Config < Cog::Config; end

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
          #: untyped
          attr_accessor :value

          # Integer
          attr_accessor :index

          #: () -> void
          def initialize
            super
            @index = 0
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'value' is required" if value.nil? && !coerce_ran?
          end

          def coerce(input_return_value)
            super
            @value = input_return_value unless @value.present?
          end
        end

        class Output < Cog::Output
          #: (Array[ExecutionManager]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
          end
        end

        # @requires_ancestor: Roast::DSL::ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Repeat
          def create_repeat_system_cog(params, input_proc)
            SystemCogs::Repeat.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              ems = [] #: Array[ExecutionManager]
              loop do
                ems << em = ExecutionManager.new(
                  @cog_registry,
                  @config_manager,
                  @all_execution_procs,
                  @workflow_context,
                  scope: params.run,
                  scope_value: input.value.deep_dup,
                  scope_index: ems.length,
                )
                em.prepare!
                em.run!
              rescue ControlFlow::Break
                # TODO: do something with the message passed to break!
                break
              end
              Output.new(ems)
            end
          end
        end
      end
    end
  end
end
