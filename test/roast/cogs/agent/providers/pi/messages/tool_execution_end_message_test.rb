# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolExecutionEndMessageTest < ActiveSupport::TestCase
              test "initialize creates message with type" do
                message = ToolExecutionEndMessage.new(type: "tool_execution_end", hash: {})

                assert_equal "tool_execution_end", message.type
              end

              test "format returns completion marker" do
                message = ToolExecutionEndMessage.new(type: "tool_execution_end", hash: {})

                assert_equal "⚙ tool execution complete", message.format
              end
            end
          end
        end
      end
    end
  end
end
