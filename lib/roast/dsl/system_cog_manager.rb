# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # @requires_ancestor: ExecutionManager
    module SystemCogManager

      private

      #: (singleton(Cog), Symbol, ^(Cog::Input) -> untyped) -> SystemCog
      def create_system_cog(cog_class, cog_name, cog_input_proc)
        case
        when cog_class == SystemCogs::Execute
          create_execute_cog(cog_name, cog_input_proc)
        else
          raise StandardError
        end
      end

      #: (Symbol, ^(Cog::Input) -> untyped) -> SystemCogs::Execute
      def create_execute_cog(cog_name, cog_input_proc)
        SystemCogs::Execute.new(cog_name, cog_input_proc) do |input|
          input = input #: as SystemCogs::Execute::Input
          raise ExecutionManager::ExecutionScopeNotSpecifiedError unless input.scope.present?

          em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, input.scope, input.value)
          em.prepare!
          em.run!

          # TODO: collect the outputs of the cogs in the execution manager that just ran and do something with them
          Cog::Output.new
        end
      end
    end
  end
end
