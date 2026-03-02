# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class TurnStartMessageTest < ActiveSupport::TestCase
              test "initialize creates message with type" do
                message = TurnStartMessage.new(type: "turn_start", hash: {})

                assert_equal "turn_start", message.type
              end

              test "format returns turn start marker" do
                message = TurnStartMessage.new(type: "turn_start", hash: {})

                assert_equal "--- turn start ---", message.format
              end
            end
          end
        end
      end
    end
  end
end
