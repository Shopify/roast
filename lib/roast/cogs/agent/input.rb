# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      # Input specification for the agent cog
      #
      # The agent cog requires a prompt that will be sent to the agent for processing.
      # Optionally, a session identifier can be provided to maintain context across multiple invocations.
      class Input < Cog::Input
        # The prompts to send to the agent for processing
        #
        # When multiple prompts are specified, each subsequent prompt is passed to the agent as soon as it completes
        # the previous one, in the same session throughout. This can be useful for helping to ensure the agent produces
        # final outputs in the form you desire after performing a long and complex task.
        #
        #: Array[String]
        attr_accessor :prompts

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
          @prompts = [] #: Array[String]
        end

        # Validate that the input has all required parameters
        #
        # This method ensures that a prompt has been provided before the agent executes.
        #
        # #### See Also
        # - `coerce`
        #
        #: () -> void
        def validate!
          raise Cog::Input::InvalidInputError, "At least one prompt is required" unless prompts.present?
          raise Cog::Input::InvalidInputError, "Blank prompts are not allowed" if prompts.any?(&:blank?)
        end

        # Coerce the input from the return value of the input block
        #
        # If the input block returns a String, it will be used as the prompt value.
        # If the input block returns an Array of Strings, the first will be used as the prompt and the
        # rest will be used as finalizers.
        #
        # #### See Also
        # - `validate!`
        #
        #: (untyped) -> void
        def coerce(input_return_value)
          case input_return_value
          when String
            self.prompts = [input_return_value]
          when Array
            self.prompts = input_return_value.map(&:to_s)
          end
        end

        #: (String) -> void
        def prompt=(prompt)
          @prompts = [prompt]
        end
      end
    end
  end
end
