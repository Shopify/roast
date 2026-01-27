# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class MessageTest < ActiveSupport::TestCase
            test "from_json parses JSON and creates message" do
              json = '{"type": "text", "text": "Hello"}'
              message = Message.from_json(json)

              assert_kind_of Messages::TextMessage, message
              assert_equal "Hello", message.text
            end

            test "from_json with assistant type creates AssistantMessage" do
              json = '{"type": "assistant", "message": {"content": []}}'
              message = Message.from_json(json)

              assert_kind_of Messages::AssistantMessage, message
            end

            test "from_json with result type creates ResultMessage" do
              json = '{"type": "result", "result": "done"}'
              message = Message.from_json(json)

              assert_kind_of Messages::ResultMessage, message
            end

            test "from_json with system type creates SystemMessage" do
              json = '{"type": "system", "message": "System prompt"}'
              message = Message.from_json(json)

              assert_kind_of Messages::SystemMessage, message
            end

            test "from_json with text type creates TextMessage" do
              json = '{"type": "text", "text": "Hello"}'
              message = Message.from_json(json)

              assert_kind_of Messages::TextMessage, message
            end

            test "from_json with tool_result type creates ToolResultMessage" do
              json = '{"type": "tool_result", "tool_use_id": "123"}'
              message = Message.from_json(json)

              assert_kind_of Messages::ToolResultMessage, message
            end

            test "from_json with tool_use type creates ToolUseMessage" do
              json = '{"type": "tool_use", "name": "test"}'
              message = Message.from_json(json)

              assert_kind_of Messages::ToolUseMessage, message
            end

            test "from_json with user type creates UserMessage" do
              json = '{"type": "user", "message": {"content": []}}'
              message = Message.from_json(json)

              assert_kind_of Messages::UserMessage, message
            end

            test "from_json with unknown type creates UnknownMessage" do
              json = '{"type": "unknown_type", "foo": "bar"}'
              message = Message.from_json(json)

              assert_kind_of Messages::UnknownMessage, message
            end

            test "from_hash with assistant type creates AssistantMessage" do
              hash = { type: :assistant, message: { content: [] } }
              message = Message.from_hash(hash)

              assert_kind_of Messages::AssistantMessage, message
            end

            test "from_hash with result type creates ResultMessage" do
              hash = { type: :result, result: "done" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::ResultMessage, message
            end

            test "from_hash with system type creates SystemMessage" do
              hash = { type: :system, message: "prompt" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::SystemMessage, message
            end

            test "from_hash with text type creates TextMessage" do
              hash = { type: :text, text: "Hello" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::TextMessage, message
            end

            test "from_hash with tool_result type creates ToolResultMessage" do
              hash = { type: :tool_result, tool_use_id: "123" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::ToolResultMessage, message
            end

            test "from_hash with tool_use type creates ToolUseMessage" do
              hash = { type: :tool_use, name: "test" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::ToolUseMessage, message
            end

            test "from_hash with user type creates UserMessage" do
              hash = { type: :user, message: { content: [] } }
              message = Message.from_hash(hash)

              assert_kind_of Messages::UserMessage, message
            end

            test "from_hash with unknown type creates UnknownMessage" do
              hash = { type: :unknown_type, foo: "bar" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::UnknownMessage, message
            end

            test "from_hash with nil type creates UnknownMessage" do
              hash = { type: nil, foo: "bar" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::UnknownMessage, message
            end

            test "from_hash removes type from hash" do
              hash = { type: :text, text: "Hello" }
              Message.from_hash(hash)

              refute hash.key?(:type)
            end

            test "from_hash converts string type to symbol" do
              hash = { type: "text", text: "Hello" }
              message = Message.from_hash(hash)

              assert_kind_of Messages::TextMessage, message
            end

            test "initialize sets session_id from hash" do
              hash = { session_id: "session_123" }
              message = Message.new(type: :test, hash:)

              assert_equal "session_123", message.session_id
            end

            test "initialize sets type" do
              hash = {}
              message = Message.new(type: :custom, hash:)

              assert_equal :custom, message.type
            end

            test "initialize removes session_id from hash" do
              hash = { session_id: "123" }
              Message.new(type: :test, hash:)

              refute hash.key?(:session_id)
            end

            test "initialize removes uuid from hash" do
              hash = { uuid: "abc-123" }
              Message.new(type: :test, hash:)

              refute hash.key?(:uuid)
            end

            test "initialize stores remaining hash in unparsed" do
              hash = { foo: "bar", baz: 123 }
              message = Message.new(type: :test, hash:)

              assert_equal "bar", message.unparsed[:foo]
              assert_equal 123, message.unparsed[:baz]
            end

            test "initialize with empty hash creates empty unparsed" do
              hash = {}
              message = Message.new(type: :test, hash:)

              assert_equal({}, message.unparsed)
            end

            test "format returns nil by default" do
              hash = {}
              message = Message.new(type: :test, hash:)
              context = Object.new

              assert_nil message.format(context)
            end
          end
        end
      end
    end
  end
end
