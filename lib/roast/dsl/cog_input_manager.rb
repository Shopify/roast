# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which an individual cog block within the `execute` block of a workflow is evaluated
    class CogInputManager
      class CogOutputAccessError < Roast::Error; end
      class CogNotYetRunError < CogOutputAccessError; end
      class CogNotDefinedError < CogOutputAccessError; end

      #: (Cog::Registry, Cog::Store) -> void
      def initialize(cog_registry, cogs)
        @cog_registry = cog_registry
        @cogs = cogs
        @context = CogInputContext.new
        bind_registered_cogs
      end

      #: CogInputContext
      attr_reader :context

      private

      #: () -> void
      def bind_registered_cogs
        @cog_registry.cogs.keys.each(&method(:bind_cog))
      end

      #: (Symbol) -> void
      def bind_cog(cog_method_name)
        cog_output_method = method(:cog_output)
        @context.instance_eval do
          define_singleton_method(cog_method_name, proc { |cog_name| cog_output_method.call(cog_name) })
        end
      end

      #: (Symbol) -> Cog::Output
      def cog_output(cog_name)
        @cogs[cog_name].tap do |cog|
          raise CogNotYetRunError unless cog.ran?
          raise CogNotDefinedError unless cog.output.present?
        end.output
      end
    end
  end
end
