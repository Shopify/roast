# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the `execute` block of a workflow is evaluated
    class ExecutionManager
      class ExecutionManagerError < Roast::Error; end
      class ExecutionManagerNotPreparedError < ExecutionManagerError; end
      class ExecutionManagerAlreadyPreparedError < ExecutionManagerError; end

      #: (Cog::Registry, Cog::Store, Cog::Stack, Array[^() -> void]) -> void
      def initialize(cog_registry, cogs, cog_stack, execution_procs)
        @cog_registry = cog_registry
        @cogs = cogs
        @cog_stack = cog_stack
        @execution_procs = execution_procs
        @execution_context = ExecutionContext.new #: ExecutionContext
        @cog_input_manager = CogInputManager.new(@cog_registry, @cogs) #: CogInputManager
      end

      #: () -> void
      def prepare!
        raise ExecutionManagerAlreadyPreparedError if preparing? || prepared?

        @preparing = true
        bind_registered_cogs
        @execution_procs.each { |ep| @execution_context.instance_eval(&ep) }
        @prepared = true
      end

      #: () -> bool
      def preparing?
        @preparing ||= false
      end

      #: () -> bool
      def prepared?
        @prepared ||= false
      end

      #: () -> CogInputContext
      def cog_input_context
        raise ExecutionManagerNotPreparedError unless prepared?

        @cog_input_manager.context
      end

      private

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
        add_cog_instance(cog_name, cog_class.new(cog_name, cog_input_proc))
      end
    end
  end
end
