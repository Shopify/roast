# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        # Input specification for the agent cog
        #
        # The agent cog requires a prompt that will be sent to the agent for processing.
        # Optionally, a session identifier can be provided to maintain context across multiple invocations.
        class Input < Cog::Input
          # The prompt to send to the agent for processing
          #
          #: String?
          attr_accessor :prompt

          # Optional session identifier for maintaining conversation context
          #
          # When provided, the agent will use this session to maintain context across
          # multiple invocations, allowing for conversational interactions.
          #
          # The agent will fork a new session from this point, so multiple agents can resume from the
          # same session state.
          #
          #: String?
          attr_accessor :session

          #: () -> void
          def initialize
            super
            @prompt = nil #: String?
          end

          # Validate that the input has all required parameters
          #
          # This method ensures that a prompt has been provided before the agent executes.
          #
          # #### See Also
          # - `coerce`
          # - `valid_prompt!`
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
              self.prompt ||= input_return_value
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
        end
      end
    end
  end
end
