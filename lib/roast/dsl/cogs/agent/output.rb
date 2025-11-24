# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        # Output from running the agent cog
        #
        # Contains the agent's final response text, session identifier for conversation continuity,
        # and statistics about the agent execution.
        class Output < Cog::Output
          include Cog::Output::WithJson
          include Cog::Output::WithText

          # The agent's final response text
          #
          # This is the text content of the agent's last message in the conversation.
          # For multi-turn conversations, this represents only the final response, not the
          # entire conversation history.
          #
          # #### See Also
          # - `text` (from WithText module)
          # - `lines` (from WithText module)
          #
          #: String
          attr_reader :response

          # The session identifier for this agent conversation
          #
          # This identifier can be used to resume the conversation in subsequent agent invocations.
          # When provided to a new agent cog's input, the agent will have access to the full
          # conversation history from this session.
          #
          # An agent resuming from this session will fork the session, so multiple agents can
          # independently resume from the same initial session and each see the same state.
          #
          #: String
          attr_reader :session

          # Statistics about the agent execution
          #
          # Contains metrics such as execution duration, number of turns (back-and-forth exchanges
          # with the agent), token usage, and per-model usage breakdown.
          #
          # #### See Also
          # - `Agent::Stats`
          #
          #: Stats
          attr_reader :stats

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
