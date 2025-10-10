# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class CogError < Roast::Error; end
      class CogAlreadyRanError < CogError; end

      class << self

        #: () -> void
        def on_create
          eigen = self
          proc do |instance_name = Random.uuid, &cog_input_proc|
            #: self as Roast::DSL::ExecutionContext
            add_cog_instance(instance_name, eigen.new(instance_name, cog_input_proc))
          end
        end

        #: () -> void
        def on_config
          eigen = self
          proc do |cog_name = nil, &configuration_proc|
            #: self as Roast::DSL::ConfigContext
            config_object = if cog_name.nil?
              fetch_general_config(eigen)
            else
              fetch_name_scoped_config(eigen, cog_name)
            end
            config_object.instance_exec(&configuration_proc) if configuration_proc
            config_object
          end
        end

        #: () -> singleton(Cog::Config)
        def config_class
          @config_class ||= find_child_config_or_default
        end

        private

        #: () -> singleton(Cog::Config)
        def find_child_config_or_default
          config_constant = "#{name}::Config"
          const_defined?(config_constant) ? const_get(config_constant) : Cog::Config # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      #: Symbol
      attr_reader :name

      #: untyped
      attr_reader :output

      #: (Symbol, Proc) -> void
      def initialize(name, cog_input_proc)
        @name = name
        @cog_input_proc = cog_input_proc #: Proc
        @output = nil #: untyped
        @finished = false #: bool

        # Make sure a config is always defined, so we don't have to worry about nils
        @config = self.class.config_class.new #: Cog::Config
      end

      #: (Cog::Config, CogInputContext) -> void
      def run!(config, input_context)
        raise CogAlreadyRanError if ran?

        @config = config
        @output = execute(input_context.instance_exec(&@cog_input_proc))
        @finished = true
      end

      #: () -> bool
      def ran?
        @finished
      end

      # Inheriting cog must implement this
      #: (untyped) -> untyped
      def execute(input)
        raise NotImplementedError
      end
    end
  end
end
