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
            end
          end
        end
      end
    end
  end
end
