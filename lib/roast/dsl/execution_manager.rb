# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the `execute` block of a workflow is evaluated
    class ExecutionManager
      class ExecutionManagerError < Roast::Error; end
      class ExecutionManagerNotPreparedError < ExecutionManagerError; end
      class ExecutionManagerAlreadyPreparedError < ExecutionManagerError; end
      class ExecutionManagerCurrentlyRunningError < ExecutionManagerError; end
      class ExecutionScopeDoesNotExistError < ExecutionManagerError; end
      class ExecutionScopeNotSpecifiedError < ExecutionManagerError; end

      #: (Cog::Registry, ConfigManager, Hash[Symbol?, Array[^() -> void]], ?Symbol?) -> void
      def initialize(cog_registry, config_manager, all_execution_procs, scope = nil)
        @cog_registry = cog_registry
        @config_manager = config_manager
        @all_execution_procs = all_execution_procs
        @scope = scope
        @cogs = Cog::Store.new #: Cog::Store
        @cog_stack = Cog::Stack.new #: Cog::Stack
        @execution_context = ExecutionContext.new #: ExecutionContext
        @cog_input_manager = CogInputManager.new(@cog_registry, @cogs) #: CogInputManager
      end

      #: () -> void
      def prepare!
        raise ExecutionManagerAlreadyPreparedError if preparing? || prepared?

        @preparing = true
        bind_registered_cogs
        my_execution_procs.each { |ep| @execution_context.instance_eval(&ep) }
        @prepared = true
      end

      def run!
        raise ExecutionManagerNotPreparedError unless prepared?
        raise ExecutionManagerCurrentlyRunningError if running?

        @running = true
        @cog_stack.map do |name, cog|
          cog.run!(
            @config_manager.config_for(cog.class, name.to_sym),
            cog_input_manager,
          )
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
      def cog_input_manager
        raise ExecutionManagerNotPreparedError unless prepared?

        @cog_input_manager.context
      end

      private

      #: () -> Array[^() -> void]
      def my_execution_procs
        raise ExecutionScopeDoesNotExistError unless @all_execution_procs.key?(@scope)

        @all_execution_procs[@scope] || []
      end

      #: (Symbol, Cog) -> void
      def add_cog_instance(name, cog)
        @cogs.insert(name, cog)
        @cog_stack.push([name, cog])
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
        cog_method = proc do |cog_name = Random.uuid, &cog_input_proc|
          on_execute_method.call(cog_class, cog_name, &cog_input_proc)
        end
        @execution_context.instance_eval do
          define_singleton_method(cog_method_name, cog_method)
        end
      end

      #: (singleton(Cog), Symbol) { (Cog::Input) -> untyped } -> void
      def on_execute(cog_class, cog_name, &cog_input_proc)
        # Called when the cog method is invoked in the workflow's 'execute' block.
        # This creates the cog instance and prepares it for execution.
        cog_instance = if cog_class == Cogs::Call
          create_special_call_cog(cog_name, cog_input_proc)
        else
          cog_class.new(cog_name, cog_input_proc)
        end
        add_cog_instance(cog_name, cog_instance)
      end

      #: (Symbol, ^(Cogs::Call::Input) -> untyped) -> Cogs::Call
      def create_special_call_cog(cog_name, cog_input_proc)
        trigger = proc do |input|
          raise ExecutionScopeNotSpecifiedError unless input.scope.present?

          em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, input.scope)
          em.prepare!
          em.run!

          # TODO: collect the outputs of the cogs in the execution manager that just ran and do something with them
        end
        Cogs::Call.new(cog_name, cog_input_proc, trigger)
      end
    end
  end
end
