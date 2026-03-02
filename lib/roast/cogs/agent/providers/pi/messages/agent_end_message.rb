# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the end of agent execution and contains the full conversation
            #
            # The `messages` array contains all user and assistant messages from the conversation.
            # The final assistant message's text content is used as the agent's response.
            #
            # Example:
            #   {"type":"agent_end","messages":[{"role":"user",...},{"role":"assistant",...}]}
            class AgentEndMessage < Message
              #: Array[Hash[Symbol, untyped]]
              attr_reader :messages

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @messages = hash.delete(:messages) || []
                super(type:, hash:)
              end

              # Extract the final response text from the last assistant message
              #
              #: () -> String
              def final_response
                last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
                return "" unless last_assistant

                (last_assistant[:content] || [])
                  .select { |c| c[:type] == "text" }
                  .map { |c| c[:text] }
                  .join
              end

              # Extract the model name from the last assistant message
              #
              #: () -> String?
              def model
                last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
                last_assistant&.dig(:model)
              end

              # Extract the final usage from the last assistant message
              #
              #: () -> Hash[Symbol, untyped]?
              def usage
                last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
                last_assistant&.dig(:usage)
              end
            end
          end
        end
      end
    end
  end
end
