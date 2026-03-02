# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class MessageTest < ActiveSupport::TestCase
            # from_json tests

            test "from_json parses JSON and creates message" do
              json = '{"type": "session", "id": "abc-123", "version": 3}'
              message = Message.from_json(json)

              assert_kind_of Messages::SessionMessage, message
              assert_equal "abc-123", message.session_id
            end

            test "from_json writes to raw dump file when provided" do
              Dir.mktmpdir do |dir|
                dump_file = Pathname.new(File.join(dir, "dump.log"))
                json = '{"type": "agent_start"}'
                Message.from_json(json, raw_dump_file: dump_file)

                assert dump_file.exist?
                assert_equal "#{json}\n", dump_file.read
              end
            end

            test "from_json appends to raw dump file" do
              Dir.mktmpdir do |dir|
                dump_file = Pathname.new(File.join(dir, "dump.log"))
                Message.from_json('{"type": "agent_start"}', raw_dump_file: dump_file)
                Message.from_json('{"type": "agent_end", "messages": []}', raw_dump_file: dump_file)

                lines = dump_file.readlines
                assert_equal 2, lines.length
              end
            end

            # from_hash dispatch tests

            test "from_hash with session type creates SessionMessage" do
              hash = { type: "session", id: "abc", version: 3 }
              message = Message.from_hash(hash)

              assert_kind_of Messages::SessionMessage, message
            end

            test "from_hash with agent_start type creates AgentStartMessage" do
              hash = { type: "agent_start" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::AgentStartMessage, message
            end

            test "from_hash with agent_end type creates AgentEndMessage" do
              hash = { type: "agent_end", messages: [] }
              message = Message.from_hash(hash)

              assert_kind_of Messages::AgentEndMessage, message
            end

            test "from_hash with turn_start type creates TurnStartMessage" do
              hash = { type: "turn_start" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::TurnStartMessage, message
            end

            test "from_hash with turn_end type creates TurnEndMessage" do
              hash = { type: "turn_end", message: {} }
              message = Message.from_hash(hash)

              assert_kind_of Messages::TurnEndMessage, message
            end

            test "from_hash with message_start type creates MessageStartMessage" do
              hash = { type: "message_start", message: { role: "user" } }
              message = Message.from_hash(hash)

              assert_kind_of Messages::MessageStartMessage, message
            end

            test "from_hash with message_update type creates MessageUpdateMessage" do
              hash = { type: "message_update", assistantMessageEvent: { type: "text_delta" } }
              message = Message.from_hash(hash)

              assert_kind_of Messages::MessageUpdateMessage, message
            end

            test "from_hash with message_end type creates MessageEndMessage" do
              hash = { type: "message_end", message: { role: "assistant" } }
              message = Message.from_hash(hash)

              assert_kind_of Messages::MessageEndMessage, message
            end

            test "from_hash with tool_execution_start type creates ToolExecutionStartMessage" do
              hash = { type: "tool_execution_start" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::ToolExecutionStartMessage, message
            end

            test "from_hash with tool_execution_end type creates ToolExecutionEndMessage" do
              hash = { type: "tool_execution_end" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::ToolExecutionEndMessage, message
            end

            test "from_hash with unknown type creates UnknownMessage" do
              hash = { type: "something_new", foo: "bar" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::UnknownMessage, message
            end

            test "from_hash with nil type creates UnknownMessage" do
              hash = { type: nil, foo: "bar" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::UnknownMessage, message
            end

            test "from_hash removes type from hash" do
              hash = { type: "session", id: "abc" }
              Message.from_hash(hash)

              refute hash.key?(:type)
            end

            # Base message tests

            test "initialize sets type" do
              message = Message.new(type: "test", hash: {})

              assert_equal "test", message.type
            end

            test "initialize stores remaining hash in unparsed" do
              hash = { foo: "bar", baz: 123 }
              message = Message.new(type: "test", hash:)

              assert_equal "bar", message.unparsed[:foo]
              assert_equal 123, message.unparsed[:baz]
            end

            test "initialize with empty hash creates empty unparsed" do
              message = Message.new(type: "test", hash: {})

              assert_equal({}, message.unparsed)
            end

            test "format returns nil by default" do
              message = Message.new(type: "test", hash: {})

              assert_nil message.format
            end
          end
        end
      end
    end
  end
end
