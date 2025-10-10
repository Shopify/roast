# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class CogAlreadyRanError < StandardError; end

      class << self
        def on_create
          eigen = self
          proc do |instance_name = Random.uuid, &action|
            #: self as Roast::DSL::WorkflowExecutionContext
            add_cog_instance(instance_name, eigen.new(instance_name, action))
          end
        end

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

        def config_class
          @config_class ||= find_child_config_or_default
        end

        private

        def find_child_config_or_default
          config_constant = "#{name}::Config"
          const_defined?(config_constant) ? const_get(config_constant) : Cog::Config # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      attr_reader :name, :output

      def initialize(name, cog_input_proc)
        @name = name
        @cog_input_proc = cog_input_proc
        @finished = false
      end

      def run!(config, cog_execution_context)
        raise CogAlreadyRanError if ran?

        @config = config
        @output = execute(cog_execution_context.instance_exec(&@cog_input_proc))
        @finished = true
      end

      def ran?
        @finished
      end

      # Inheriting cog must implement this
      def execute(input)
        raise NotImplementedError
      end
    end
  end
end
