# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Call < SystemCog
        class Input < Cog::Input
          #: Symbol?
          attr_accessor :scope

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'scope' is required" unless scope.present?
          end

          #: (Symbol) -> void
          def coerce(input_return_value)
            case input_return_value
            when Symbol
              self.scope = input_return_value
            end
          end
        end

        # @requires_ancestor: ExecutionManager
        module Manager
          private

          #: (Symbol, ^(Cog::Input) -> untyped) -> SystemCogs::Call
          def create_call_system_cog(name, input_proc)
            SystemCogs::Call.new(name, input_proc) do |input|
              input = input #: as SystemCogs::Call::Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless input.scope.present?

              em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, input.scope)
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
