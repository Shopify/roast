# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which an individual cog block within the `execute` block of a workflow is evaluated
    class CogInputContext
      class CogExecutionAccessError < Roast::Error; end

      # Raises if you access a cog in an execution block that hasn't already been run.
      class IncompleteCogExecutionAccessError < CogExecutionAccessError; end

      class MissingCogOutputError < CogExecutionAccessError; end

      #: (Cog::Store, Array[Symbol]) -> void
      def initialize(cogs, bound_names)
        @cogs = cogs #: Cog::Store
        bind_cog_output_methods(bound_names)
      end

      private

      #: (Array[Symbol]) -> void
      def bind_cog_output_methods(bound_names)
        bound_names.map do |name|
          define_singleton_method(name, ->(name) do
            @cogs[name].tap do |cog|
              raise IncompleteCogExecutionAccessError unless cog.ran?
              raise MissingCogOutputError unless cog.output.present?
            end.output
          end)
        end
      end
    end
  end
end
