# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which an individual cog block within the `execute` block of a workflow is evaluated
    class CogInputManager
      class CogOutputAccessError < Roast::Error; end

      class CogDoesNotExistError < CogOutputAccessError; end

      class CogNotYetRunError < CogOutputAccessError; end

      class CogSkippedError < CogOutputAccessError; end

      class CogFailedError < CogOutputAccessError; end

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
        cog_question_method_name = (cog_method_name.to_s + "?").to_sym
        cog_bang_method_name = (cog_method_name.to_s + "!").to_sym
        cog_output_method = method(:cog_output)
        cog_output_question_method = method(:cog_output?)
        cog_output_bang_method = method(:cog_output!)
        @context.instance_eval do
          define_singleton_method(cog_method_name, proc { |cog_name| cog_output_method.call(cog_name) })
          define_singleton_method(cog_question_method_name, proc { |cog_name| cog_output_question_method.call(cog_name) })
          define_singleton_method(cog_bang_method_name, proc { |cog_name| cog_output_bang_method.call(cog_name) })
        end
      end

      #: (Symbol) -> Cog::Output?
      def cog_output(cog_name)
        cog_output!(cog_name)
      rescue CogOutputAccessError => e
        # Even this method should raise an exception if the requested cog does not exist at all
        raise e if e.is_a?(CogDoesNotExistError)

        nil
      end

      #: (Symbol) -> bool
      def cog_output?(cog_name)
        !cog_output(cog_name).nil?
      end

      #: (Symbol) -> Cog::Output
      def cog_output!(cog_name)
        raise CogDoesNotExistError, cog_name unless @cogs.key?(cog_name)

        @cogs[cog_name].tap do |cog|
          raise CogNotYetRunError, cog_name unless cog.ran?
          raise CogSkippedError, cog_name if cog.skipped?
          raise CogFailedError, cog_name if cog.failed?
        end.output
      end
    end
  end
end
