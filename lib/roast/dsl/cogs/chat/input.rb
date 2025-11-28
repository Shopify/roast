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

          # Optional session identifier for maintaining conversation context
          #
          # When provided, the chat cog will use this session to maintain context across
          # multiple invocations, allowing for conversational interactions.
          #
          # The chat cog will fork a new session from this point, so multiple conversations can be resumed
          # from the same session state.
          #
          #: Session?
          attr_accessor :session

          # Validate that the input has all required parameters
          #
          # This method ensures that a prompt has been provided before the chat cog executes.
          #
          # #### See Also
          # - `coerce`
          #
          #: () -> void
          def validate!
            valid_prompt!
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

          # Get the validated prompt value
          #
          # Returns the prompt if it is present, otherwise raises an `InvalidInputError`.
          #
          # #### See Also
          # - `prompt`
          # - `validate!`
          #
          #: () -> String
          def valid_prompt!
            valid_prompt = @prompt
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless valid_prompt.present?

            valid_prompt
          end

          # Get the session value if one was provided
          #
          # Returns the session object if present, otherwise returns `nil`.
          # This method does not raise an error when the session is absent; providing a session is optional.
          #
          # #### See Also
          # - `session`
          #
          #: () -> Session?
          def valid_session
            @session
          end
        end
      end
    end
  end
end
