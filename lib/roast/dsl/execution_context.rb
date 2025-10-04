# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext
      def initialize(cogs, cog_stack, execution_proc)
        @cogs = cogs
        @cog_stack = cog_stack
        @execution_proc = execution_proc
      end

      def prepare!
        bind_default_cogs
        instance_eval(&@execution_proc)
      end

      private

      def add_cog_instance(name, cog)
        @cogs.insert(name, cog)
        @cog_stack.push([name, cog])
      end

      #: () -> void
      def bind_default_cogs
        bind_cog(Cogs::Cmd, :cmd)
      end

      def bind_cog(cog_class, name)
        instance_eval do
          define_singleton_method(name, &cog_class.on_create)
        end
      end
    end
  end
end
