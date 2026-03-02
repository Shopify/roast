# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class MessageTest < ActiveSupport::TestCase
            test "from_json parses valid JSON" do
              json = '{"type":"session","id":"abc123","version":3,"timestamp":"2026-01-01","cwd":"/tmp"}'
              message = Message.from_json(json)

              assert_kind_of Messages::SessionMessage, message
              assert_equal "abc123", message.session_id
            end

            test "from_hash dispatches session type" do
              message = Message.from_hash({ type: "session", id: "abc" })

              assert_kind_of Messages::SessionMessage, message
            end

            test "from_hash dispatches agent_start type" do
              message = Message.from_hash({ type: "agent_start" })

              assert_kind_of Messages::AgentStartMessage, message
            end

            test "from_hash dispatches turn_start type" do
              message = Message.from_hash({ type: "turn_start" })

              assert_kind_of Messages::TurnStartMessage, message
            end

            test "from_hash dispatches turn_end type" do
              message = Message.from_hash({ type: "turn_end", message: {}, toolResults: [] })

              assert_kind_of Messages::TurnEndMessage, message
            end

            test "from_hash dispatches message_start type" do
              message = Message.from_hash({ type: "message_start", message: {} })

              assert_kind_of Messages::MessageStartMessage, message
            end

            test "from_hash dispatches message_end type" do
              message = Message.from_hash({ type: "message_end", message: {} })

              assert_kind_of Messages::MessageEndMessage, message
            end

            test "from_hash dispatches unknown type" do
              message = Message.from_hash({ type: "something_new", data: 123 })

              assert_kind_of Messages::UnknownMessage, message
            end
          end
        end
      end
    end
  end
end
