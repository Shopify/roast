# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Marks the end of a tool execution
            #
            # Emitted when Pi has finished executing a tool call.
            #
            # Example:
            #   {"type":"tool_execution_end"}
            class ToolExecutionEndMessage < Message
            end
          end
        end
      end
    end
  end
end
