# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Represents a tool execution result from the Pi agent
            #
            # In Pi's JSON protocol, tool results appear as `tool_execution_end` events
            # containing the result content and error status.
            class ToolResultMessage
              #: String?
              attr_reader :tool_call_id

              #: String?
              attr_reader :tool_name

              #: String?
              attr_reader :content

              #: bool
              attr_reader :is_error

              #: (tool_call_id: String?, tool_name: String?, content: String?, is_error: bool) -> void
              def initialize(tool_call_id:, tool_name:, content:, is_error:)
                @tool_call_id = tool_call_id
                @tool_name = tool_name
                @content = content
                @is_error = is_error
              end

              #: (PiInvocation::Context) -> String?
              def format(context)
                tool_call = context.tool_call(tool_call_id)
                name = tool_name || tool_call&.name || "unknown"
                status = is_error ? "ERROR" : "OK"

                # Truncate long tool results for progress display
                c = content
                display_content = if c && c.length > 200
                  "#{c[0..197]}..."
                else
                  c
                end

                "#{name.upcase} #{status}#{display_content ? " #{display_content}" : ""}"
              end
            end
          end
        end
      end
    end
  end
end
