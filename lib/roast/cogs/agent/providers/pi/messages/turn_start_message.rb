# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the beginning of a new turn (request/response cycle)
            #
            # Example:
            #   {"type":"turn_start"}
            class TurnStartMessage < Message
              #: () -> String
              def format
                "--- turn start ---"
              end
            end
          end
        end
      end
    end
  end
end
