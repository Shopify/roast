# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Contains the cogs already executed in this run.
    class CogExecutionContext
      # Raises if you access a cog in an execution block that hasn't already been run.
      class IncompleteCogExecutionAccessError < StandardError; end

      def initialize(cogs, bound_names)
        @cogs = cogs
        bind_cog_methods(bound_names)
      end

      private

      def bind_cog_methods(bound_names)
        bound_names.map do |name|
          define_singleton_method(name.to_sym, ->(name) do
            @cogs[name].tap do |cog|
              raise IncompleteCogExecutionAccessError unless cog.ran?
            end.output
          end)
        end
      end
    end
  end
end
