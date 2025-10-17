# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class CogError < Roast::Error; end

      class CogAlreadyRanError < CogError; end

      class << self
        #: () -> singleton(Cog::Config)
        def config_class
          @config_class ||= find_child_config_or_default
        end

        #: () -> singleton(Cog::Input)
        def input_class
          @input_class ||= find_child_input_or_default #: singleton(Cog::Input)?
        end

        private

        #: () -> singleton(Cog::Config)
        def find_child_config_or_default
          config_constant = "#{name}::Config"
          const_defined?(config_constant) ? const_get(config_constant) : Cog::Config # rubocop:disable Sorbet/ConstantsFromStrings
        end

        #: () -> singleton(Cog::Input)
        def find_child_input_or_default
          input_constant = "#{name}::Input"
          const_defined?(input_constant) ? const_get(input_constant) : Cog::Input # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      #: Symbol
      attr_reader :name

      #: Cog::Output?
      attr_reader :output

      #: (Symbol, ^(Cog::Input) -> untyped) -> void
      def initialize(name, cog_input_proc)
        @name = name
        @cog_input_proc = cog_input_proc #: ^(Cog::Input) -> untyped
        @output = nil #: Cog::Output?
        @finished = false #: bool

        # Make sure a config is always defined, so we don't have to worry about nils
        @config = self.class.config_class.new #: Cog::Config
      end

      #: (Cog::Config, CogInputContext) -> void
      def run!(config, input_context)
        raise CogAlreadyRanError if ran?

        @config = config
        input_instance = self.class.input_class.new
        input_return = input_context.instance_exec(input_instance, &@cog_input_proc) if @cog_input_proc
        coerce_and_validate_input!(input_instance, input_return)
        @output = execute(input_instance)
        @finished = true
      end

      #: () -> bool
      def ran?
        @finished
      end

      # Inheriting cog must implement this
      #: (Cog::Input) -> Cog::Output
      def execute(input)
        raise NotImplementedError
      end

      private

      #: (Cog::Input, untyped) -> void
      def coerce_and_validate_input!(input, return_value)
        # Check if the input is already valid
        input.validate!
      rescue Cog::Input::InvalidInputError
        # If it's not valid, attempt to coerce if possible
        input.coerce(return_value)
        # Re-validate because coerce! should not be responsible for validation
        input.validate!
      end
    end
  end
end
