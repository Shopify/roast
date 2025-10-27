# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class SystemCog < Cog
      class << self
        #: () -> singleton(SystemCog::Params)
        def params_class
          @params_class ||= find_child_params_or_default
        end

        private

        #: () -> singleton(SystemCog::Params)
        def find_child_params_or_default
          config_constant = "#{name}::Params"
          const_defined?(config_constant) ? const_get(config_constant) : SystemCog::Params # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      #: (Symbol, ^(Cog::Input) -> untyped) { (Cog::Input, Cog::Config) -> Cog::Output } -> void
      def initialize(name, cog_input_proc, &on_execute)
        super(name, cog_input_proc)
        @on_execute = on_execute
      end

      #: (Cog::Input) -> Cog::Output
      def execute(input)
        # The `on_execute` callback allows a system cog to pass its execution back to the ExecutionManager
        # for special handling.
        @on_execute.call(input, @config)
      end
    end
  end
end
