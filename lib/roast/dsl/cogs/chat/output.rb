# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        # Output from running the chat cog
        #
        # Contains the LLM's response text from a chat completion request.
        # The output provides convenient access to the response as plain text, parsed JSON,
        # or as an array of lines through the included `WithText` and `WithJson` modules.
        class Output < Cog::Output
          include Cog::Output::WithJson
          include Cog::Output::WithNumber
          include Cog::Output::WithText

          # The LLM's response text
          #
          # This is the complete text response returned by the language model for the chat request.
          # The response can be accessed directly, or through convenience methods like `text`,
          # `lines`, `json`, or `json!` provided by the included modules.
          #
          # #### See Also
          # - `text` (from WithText module)
          # - `lines` (from WithText module)
          # - `json` (from WithJson module)
          # - `json!` (from WithJson module)
          #
          #: String
          attr_reader :response

          # The session object containing the conversation context
          #
          # This holds a reference to the complete message history needed to resume or continue a conversation
          # with the language model. The session can be passed to subsequent `chat` cog invocations
          # to maintain conversational context.
          #
          # Note: you do __not__ have to use the same model for the entire conversation.
          # You can change models between prompts while maintaining the same session, allowing
          # different models to participate in the same conversation.
          #
          #: Session
          attr_reader :session

          # Initialize a new chat output with the session and response text
          #
          #: (Session, String) -> void
          def initialize(session, response)
            super()
            @session = session
            @response = response
          end

          private

          def raw_text
            response
          end
        end
      end
    end
  end
end
