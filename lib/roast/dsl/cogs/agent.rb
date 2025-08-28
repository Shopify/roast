# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Roast::DSL::Cog
        DEFAULT_NAME = :agent

        #: (String | Symbol | nil) -> void
        def initialize(name_or_prompt = nil)
          if name_or_prompt.is_a?(String)
            @name = DEFAULT_NAME
            @prompt = name_or_prompt
          elsif name_or_prompt.is_a?(Symbol)
            @name = name_or_prompt
            @prompt = nil
          else
            raise ArgumentError, "agent() requires a string prompt or symbol name, got: #{name_or_prompt.class}"
          end

          @agent = Roast::LLM::Agent.new(@name)

          super(@name)
        end

        # @override
        #: () -> void
        def on_invoke
          @agent.prompt(@prompt) unless @prompt.nil?
        end

        # @override
        #: () -> String
        def output
          @agent.last_response
        end

        #: (String) -> String
        def prompt(text)
          @agent.prompt(text)
        end

        # TODO: Some slick merge-em-all configuration stuff.
        #: (Proc) -> void
        def config(&block)
          @agent.config(&block)
        end
      end
    end
  end
end
