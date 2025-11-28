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

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end

          private

          def json_text
            response
          end

          def raw_text
            response
          end
        end
      end
    end
  end
end
