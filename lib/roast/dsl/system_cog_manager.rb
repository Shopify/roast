# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # @requires_ancestor: ExecutionManager
    module SystemCogManager

      private

      #: (singleton(SystemCog), Symbol, Array[untyped], Hash[Symbol, untyped], ^(Cog::Input) -> untyped) -> SystemCog
      def create_system_cog(cog_class, cog_name, cog_args, cog_kwargs, cog_input_proc)
        cog_params = T.unsafe(cog_class).params_class.new(cog_name, *cog_args, **cog_kwargs)
        case
        when cog_class == SystemCogs::Execute
          create_execute_cog(cog_name, cog_params, cog_input_proc)
        when cog_class == SystemCogs::Map
          create_map_cog(cog_name, cog_params, cog_input_proc)
        else
          raise NotImplementedError, "No manager defined for #{cog_class}"
        end
      end


      #: (Symbol, SystemCog::Params, ^(Cog::Input) -> untyped) -> SystemCogs::Execute
      def create_execute_cog(name, _params, input_proc)
        SystemCogs::Execute.new(name, input_proc) do |input|
          input = input #: as SystemCogs::Execute::Input
          raise ExecutionManager::ExecutionScopeNotSpecifiedError unless input.scope.present?

          em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, input.scope, input.value)
          em.prepare!
          em.run!

          # TODO: collect the outputs of the cogs in the execution manager that just ran and do something with them
          Cog::Output.new
        end
      end

      #: (Symbol, SystemCog::Params, ^(Cog::Input) -> untyped) -> SystemCogs::Map
      def create_map_cog(name, params, input_proc)
        SystemCogs::Map.new(name, input_proc) do |input|
          input = input #: as SystemCogs::Map::Input
          params = params #: as SystemCogs::Map::Params

          # For now, just process each item sequentially in a single thread
          input.items.each do |item|
            em = ExecutionManager.new(
              @cog_registry, @config_manager, @all_execution_procs,
              params.map_executor_scope, item)
            em.prepare!
            em.run!
          end

          Cog::Output.new
        end
      end
    end
  end
end
