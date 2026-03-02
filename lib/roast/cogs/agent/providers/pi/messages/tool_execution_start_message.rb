# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the start of a tool execution
            #
            # Emitted when Pi begins executing a tool call.
            #
            # Example:
            #   {"type":"tool_execution_start"}
            class ToolExecutionStartMessage < Message
            end
          end
        end
      end
    end
  end
end
