# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Call < SystemCog
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
          #: () -> void
          def validate!; end
        end

        # @requires_ancestor: ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Call
          def create_call_system_cog(params, input_proc)
            SystemCogs::Call.new(params.name, input_proc) do |_input|
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.scope.present?

              em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, params.scope)
              em.prepare!
              em.run!

              Cog::Output.new
            end
          end
        end
      end
    end
  end
end
