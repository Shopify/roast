# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the end of a turn and contains usage statistics
            #
            # Each turn represents one complete request/response cycle. The message contains
            # the final assistant message state and usage data for that turn.
            #
            # Example:
            #   {"type":"turn_end","message":{"role":"assistant","model":"claude-opus-4-6",
            #     "usage":{"input":3,"output":5,"cost":{"total":0.028}},...},"toolResults":[]}
            class TurnEndMessage < Message
              #: Hash[Symbol, untyped]?
              attr_reader :message

              #: Array[Hash[Symbol, untyped]]
              attr_reader :tool_results

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @message = hash.delete(:message)
                @tool_results = hash.delete(:toolResults) || []
                super(type:, hash:)
              end

              # The model used for this turn
              #
              #: () -> String?
              def model
                @message&.dig(:model)
              end

              # The usage data for this turn
              #
              #: () -> Hash[Symbol, untyped]?
              def usage
                @message&.dig(:usage)
              end

              # The content of the assistant message for this turn
              #
              #: () -> Array[Hash[Symbol, untyped]]
              def content
                @message&.dig(:content) || []
              end

              # The stop reason for this turn
              #
              #: () -> String?
              def stop_reason
                @message&.dig(:stopReason)
              end
            end
          end
        end
      end
    end
  end
end
