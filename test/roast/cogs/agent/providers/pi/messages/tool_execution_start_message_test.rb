# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolExecutionStartMessageTest < ActiveSupport::TestCase
              test "initialize creates message with type" do
                message = ToolExecutionStartMessage.new(type: "tool_execution_start", hash: {})

                assert_equal "tool_execution_start", message.type
              end
            end
          end
        end
      end
    end
  end
end
