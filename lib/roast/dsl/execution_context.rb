# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the `execute` block of a workflow is evaluated
    class ExecutionContext
      class ExecutionContextError < Roast::Error; end
      class ExecutionContextNotPreparedError < ExecutionContextError; end
      class ExecutionContextAlreadyPreparedError < ExecutionContextError; end

      #: (Cog::Store, Cog::Stack, Array[^() -> void]) -> void
      def initialize(cogs, cog_stack, execution_procs)
        @cogs = cogs #: Cog::Store
        @cog_stack = cog_stack #: Cog::Stack
        @execution_procs = execution_procs #: Array[^() -> void]
        @bound_names = [] #: Array[Symbol]
      end

      #: () -> void
      def prepare!
        raise ExecutionContextAlreadyPreparedError if prepared?

        bind_default_cogs
        @execution_procs.each { |ep| instance_eval(&ep) }
        @prepared = true
      end

      #: () -> bool
      def prepared?
        @prepared ||= false #: bool?
      end

      #: () -> CogInputContext
      def cog_input_context
        raise ExecutionContextNotPreparedError unless prepared?

        @cog_input_context ||= CogInputContext.new(@cogs, @bound_names) #: CogInputContext?
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
      def bind_default_cogs
        bind_cog(Cogs::Cmd, :cmd)
        bind_cog(Cogs::Chat, :chat)
      end

      #: (singleton(Cog), Symbol) -> void
      def bind_cog(cog_class, name)
        @bound_names << name
        instance_eval do
          define_singleton_method(name, &cog_class.on_execute)
        end
      end
    end
  end
end
