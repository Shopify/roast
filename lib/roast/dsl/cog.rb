# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class << self
        def on_create
          eigen = self
          proc do |instance_name = Random.uuid, &action|
            #: self as Roast::DSL::ExecutionContext
            add_cog_instance(instance_name, eigen.new(action))
          end
        end

        def on_config
          eigen = self
          proc do |cog_name = nil, &configuration|
            #: self as Roast::DSL::ConfigContext
            config_object = if cog_name.nil?
              fetch_execution_scope(eigen)
            else
              fetch_or_create_cog_config(eigen, cog_name)
            end

            config_object.instance_exec(&configuration) if configuration
          end
        end

        def config_class
          @config_class ||= find_child_config_or_default
        end

        private

        def find_child_config_or_default
          config_constant = "#{name}::Config"
          const_defined?(config_constant) ? const_get(config_constant) : Cog::Config # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      attr_reader :output

      def initialize(cog_input_proc)
        @cog_input_proc = cog_input_proc
      end

      def input
        @cog_input_proc.call
      end

      def run!(config)
        @config = config
        @output = execute
      end

      # Inheriting cog must implement this
      def execute
        raise NotImplementedError
      end
    end
  end
end
