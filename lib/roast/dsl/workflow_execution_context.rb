# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class WorkflowExecutionContext
      def initialize(cogs, cog_stack, execution_proc)
        @cogs = cogs
        @cog_stack = cog_stack
        @execution_proc = execution_proc
        @bound_names = []
      end

      def prepare!
        bind_default_cogs
        instance_eval(&@execution_proc)
      end

      def cog_execution_context
        @cog_execution_context ||= CogExecutionContext.new(@cogs, @bound_names)
      end

      private

      def add_cog_instance(name, cog)
        @cogs.insert(name, cog)
        @cog_stack.push([name, cog])
      end

      def output(name)
        @cogs[name].output
      end

      #: () -> void
      def bind_default_cogs
        bind_cog(Cogs::Cmd, :cmd)
      end

      def bind_cog(cog_class, name)
        @bound_names << name
        instance_eval do
          define_singleton_method(name, &cog_class.on_create)
        end
      end
    end
  end
end
