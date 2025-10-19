# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class SystemCog < Cog
      #: (Symbol, ^(Cog::Input) -> untyped) { (Cog::Input) -> Cog::Output } -> void
      def initialize(name, cog_input_proc, &on_execute)
        super(name, cog_input_proc)
        @on_execute = on_execute
      end

      #: (Cog::Input) -> Cog::Output
      def execute(input)
        # The `on_execute` callback allows a system cog to pass its execution back to the ExecutionManager
        # for special handling.
        @on_execute.call(input)
      end
    end
  end
end
