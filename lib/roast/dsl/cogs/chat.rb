# frozen_string_literal: true
# typed: true

module Roast
  module DSL
    module Cogs
      class Chat < Roast::DSL::Cog
        DEFAULT_NAME = :chat

        #: (String | Symbol | nil) -> void
        def initialize(name_or_prompt = nil)
          if name_or_prompt.is_a?(String)
            @name = DEFAULT_NAME
            @prompt = name_or_prompt
          elsif name_or_prompt.is_a?(Symbol)
            @name = name_or_prompt
            @prompt = nil
          elsif name_or_prompt.nil?
            @name = DEFAULT_NAME
            @prompt = nil
          else
            raise ArgumentError, "chat() requires a string prompt or symbol name, got: #{name_or_prompt.class}"
          end

          @chat = Roast::LLM::Chat.new(@name)

          super(@name)
        end

        # @override
        #: () -> void
        def on_invoke
          @chat.prompt(@prompt) unless @prompt.nil?
        end

        # @override
        #: () -> String
        def output
          @chat.output
        end

        #: (String) -> String
        def prompt(text)
          @chat.prompt(text)
        end

        # TODO: Some merge-em-all config stuff.
        #: (Proc) -> void
        def config(&block)
          @chat.config(&block)
        end
      end
    end
  end
end
