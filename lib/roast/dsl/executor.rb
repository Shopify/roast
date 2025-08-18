# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class << self
        def from_file(workflow_path)
          execute(File.read(workflow_path))
        end

        private

        def execute(input)
          new.instance_eval(input)
        end
      end

      def initialize
        @agent_context = {} #: Hash[Symbol, Roast::DSL::Agent]
      end

      # Define methods to be used in workflows below.

      def shell(command_string)
        puts %x(#{command_string})
      end

      # The :default agent uses whatever the default model of the workflow is.
      # This avoids needless boilerplate when you don't have multiple agent types
      # and don't need to customize anything.
      #: (?Symbol) -> Roast::DSL::Agent
      def agent(name = :default, &block)
        if @agent_context[name]
          @agent_context[name]
        else


        @agent_context[name] = build_agent(name)
        end
      end

      private

      def build_agent(name = :default)
        Roast::DSL::Agent.new(name)
      end
    end
  end
end
