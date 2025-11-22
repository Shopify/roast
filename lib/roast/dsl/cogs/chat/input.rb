# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        # Input specification for the chat cog
        #
        # The chat cog requires a prompt that will be sent to the language model for processing.
        # This enables single-turn interactions with the LLM without maintaining conversation context.
        class Input < Cog::Input
          # The prompt to send to the language model for processing
          #
          # #### Notes
          # The chat cog does not maintain any conversational context with the LLM provider.
          # If you want the LLM to be aware of previous conversational history, you must provide the full
          # transcript (or relevant subset) in the prompt.
          #
          #: String?
          attr_accessor :prompt

          # Validate that the input has all required parameters
          #
          # This method ensures that a prompt has been provided before the chat cog executes.
          #
          # #### See Also
          # - `coerce`
          #
          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless prompt.present?
          end

          # Coerce the input from the return value of the input block
          #
          # If the input block returns a String, it will be used as the prompt value.
          #
          # #### See Also
          # - `validate!`
          #
          #: (untyped) -> void
          def coerce(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt = input_return_value
            end
          end
        end
      end
    end
  end
end
