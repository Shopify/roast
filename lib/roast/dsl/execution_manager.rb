# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the `execute` block of a workflow is evaluated
    class ExecutionManager
      include SystemCogs::Call::Manager
      include SystemCogs::Map::Manager

      class ExecutionManagerError < Roast::Error; end

      class ExecutionManagerNotPreparedError < ExecutionManagerError; end

      class ExecutionManagerAlreadyPreparedError < ExecutionManagerError; end

      class ExecutionManagerCurrentlyRunningError < ExecutionManagerError; end

      class ExecutionScopeDoesNotExistError < ExecutionManagerError; end

      class ExecutionScopeNotSpecifiedError < ExecutionManagerError; end

      class IllegalCogNameError < ExecutionManagerError; end

      class OutputsAlreadyDefinedError < ExecutionManagerError; end

      #: (
      #|  Cog::Registry,
      #|  ConfigManager,
      #|  Hash[Symbol?, Array[^() -> void]],
      #|  WorkflowContext,
      #|  ?scope: Symbol?,
      #|  ?scope_value: untyped?,
      #|  ?scope_index: Integer
      #| ) -> void
      def initialize(
        cog_registry,
        config_manager,
        all_execution_procs,
        workflow_context,
        scope: nil,
        scope_value: nil,
        scope_index: 0
      )
        @cog_registry = cog_registry
        @config_manager = config_manager
        @all_execution_procs = all_execution_procs
        @workflow_context = workflow_context
        @scope = scope
        @scope_value = scope_value
        @scope_index = scope_index
        @cogs = Cog::Store.new #: Cog::Store
        @cog_stack = Cog::Stack.new #: Cog::Stack
        @execution_context = ExecutionContext.new #: ExecutionContext
        @cog_input_manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context) #: CogInputManager
      end

      #: () -> void
      def prepare!
        raise ExecutionManagerAlreadyPreparedError if preparing? || prepared?

        @preparing = true
        bind_outputs
        bind_registered_cogs
        my_execution_procs.each { |ep| @execution_context.instance_eval(&ep) }
        @prepared = true
      end

      def run!
        raise ExecutionManagerNotPreparedError unless prepared?
        raise ExecutionManagerCurrentlyRunningError if running?

        @running = true
        Sync do
          cog_tasks = @cog_stack.map do |cog|
            cog_config = @config_manager.config_for(cog.class, cog.name)
            cog_task = cog.run!(
              cog_config.deep_dup,
              cog_input_context,
              @scope_value.deep_dup, # Pass a copy to each cog to guard against mutated values being passed between cogs
              @scope_index,
            )
            cog_task.wait unless cog_config.async?
            cog_task
          end
          cog_tasks.map(&:wait)
        end
        @running = false
      end

      #: () -> bool
      def preparing?
        @preparing ||= false
      end

      #: () -> bool
      def prepared?
        @prepared ||= false
      end

      #: () -> bool
      def running?
        @running ||= false
      end

      #: () -> CogInputContext
      def cog_input_context
        raise ExecutionManagerNotPreparedError unless prepared?

        @cog_input_manager.context
      end

      private

      #: () -> Array[^() -> void]
      def my_execution_procs
        raise ExecutionScopeDoesNotExistError, @scope unless @all_execution_procs.key?(@scope)

        @all_execution_procs[@scope] || []
      end

      #: (Cog) -> void
      def add_cog_instance(cog)
        @cogs.insert(cog)
        @cog_stack.push(cog)
      end

      # TODO: add typing for output
      #: (Symbol) -> untyped
      def output(name)
        @cogs[name].output
      end

      #: () -> void
      def bind_registered_cogs
        @cog_registry.cogs.each { |cog_method_name, cog_class| bind_cog(cog_method_name, cog_class) }
      end

      #: (Symbol, singleton(Cog)) -> void
      def bind_cog(cog_method_name, cog_class)
        on_execute_method = method(:on_execute)
        cog_method = proc do |*args, **kwargs, &cog_input_proc|
          on_execute_method.call(cog_class, args, kwargs, cog_input_proc)
        end
        @execution_context.instance_eval do
          raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)

          define_singleton_method(cog_method_name, cog_method)
        end
      end

      #: (singleton(Cog), Array[untyped], Hash[Symbol, untyped], ^(Cog::Input) -> untyped) -> void
      def on_execute(cog_class, cog_args, cog_kwargs, cog_input_proc)
        # Called when the cog method is invoked in the workflow's 'execute' block.
        # This creates the cog instance and prepares it for execution.
        if cog_class <= SystemCog
          untyped_cog_class = cog_class #: as untyped // to remove warning about splats of unknown length
          cog_params = untyped_cog_class.params_class.new(*cog_args, **cog_kwargs)
          cog_instance = if cog_class == SystemCogs::Call
            create_call_system_cog(cog_params, cog_input_proc)
          elsif cog_class == SystemCogs::Map
            create_map_system_cog(cog_params, cog_input_proc)
          else
            raise NotImplementedError, "No system cog manager defined for #{cog_class}"
          end
        else
          cog_name = Array.wrap(cog_args).shift || Cog.generate_fallback_name
          cog_instance = cog_class.new(cog_name, cog_input_proc)
        end
        add_cog_instance(cog_instance)
      end

      def bind_outputs
        on_outputs_method = method(:on_outputs)
        method_to_bind = proc do |&outputs_proc|
          on_outputs_method.call(outputs_proc)
        end
        @execution_context.instance_eval do
          define_singleton_method(:outputs, method_to_bind)
        end
      end

      #: (^(untyped, Integer) -> untyped) -> void
      def on_outputs(outputs)
        raise OutputsAlreadyDefinedError if @outputs

        @outputs = outputs
      end

      #: () -> untyped
      def final_output
        return @cog_input_manager.context.instance_exec(@scope_value, @scope_index, &@outputs) if @outputs

        last_cog = @cog_stack.last
        raise CogInputManager::CogDoesNotExistError, "no cogs defined in scope" unless last_cog

        last_cog.output
      end
    end
  end
end
