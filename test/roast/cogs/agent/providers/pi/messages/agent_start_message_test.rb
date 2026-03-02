# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class AgentStartMessageTest < ActiveSupport::TestCase
              test "initialize creates message with type" do
                message = AgentStartMessage.new(type: "agent_start", hash: {})

                assert_equal "agent_start", message.type
              end

              test "initialize stores unparsed fields" do
                hash = { extra: "data" }
                message = AgentStartMessage.new(type: "agent_start", hash:)

                assert_equal "data", message.unparsed[:extra]
              end
            end
          end
        end
      end
    end
  end
end
