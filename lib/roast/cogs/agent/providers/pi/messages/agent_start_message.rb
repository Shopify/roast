# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the beginning of agent execution
            #
            # Example:
            #   {"type":"agent_start"}
            class AgentStartMessage < Message
            end
          end
        end
      end
    end
  end
end
