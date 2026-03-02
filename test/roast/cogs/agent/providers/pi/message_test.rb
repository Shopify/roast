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

            test "from_hash dispatches agent_end type" do
              message = Message.from_hash({ type: "agent_end", messages: [] })

              assert_kind_of Messages::AgentEndMessage, message
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

            # message_update sub-dispatch tests

            test "from_hash dispatches message_update text_delta" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "text_delta", delta: "Hello", contentIndex: 0 },
              })

              assert_kind_of Messages::TextDeltaMessage, message
              assert_equal "Hello", message.delta
            end

            test "from_hash dispatches message_update text_start" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "text_start", contentIndex: 0, partial: {} },
              })

              assert_kind_of Messages::TextStartMessage, message
            end

            test "from_hash dispatches message_update text_end" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "text_end", content: "Final text", contentIndex: 0, partial: {} },
              })

              assert_kind_of Messages::TextEndMessage, message
              assert_equal "Final text", message.content
            end

            test "from_hash dispatches message_update thinking_delta" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "thinking_delta", delta: "Thinking...", contentIndex: 0 },
              })

              assert_kind_of Messages::ThinkingDeltaMessage, message
              assert_equal "Thinking...", message.delta
            end

            test "from_hash dispatches message_update thinking_start" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "thinking_start", contentIndex: 0, partial: {} },
              })

              assert_kind_of Messages::ThinkingStartMessage, message
            end

            test "from_hash dispatches message_update thinking_end" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "thinking_end", content: "Full thought", contentIndex: 0, partial: {} },
              })

              assert_kind_of Messages::ThinkingEndMessage, message
              assert_equal "Full thought", message.content
            end

            test "from_hash dispatches message_update toolcall_start" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: {
                  type: "toolcall_start",
                  contentIndex: 1,
                  partial: {
                    content: [
                      { type: "toolCall", id: "tool_1", name: "bash", arguments: {} },
                    ],
                  },
                },
              })

              assert_kind_of Messages::ToolCallStartMessage, message
              assert_equal "tool_1", message.tool_call_id
              assert_equal :bash, message.name
            end

            test "from_hash dispatches message_update toolcall_delta" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "toolcall_delta", delta: '{"command": "ls' },
              })

              assert_kind_of Messages::ToolCallDeltaMessage, message
              assert_equal '{"command": "ls', message.delta
            end

            test "from_hash dispatches message_update toolcall_end" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: {
                  type: "toolcall_end",
                  toolCall: { id: "tool_1", name: "bash", arguments: { command: "ls -la" } },
                },
              })

              assert_kind_of Messages::ToolCallEndMessage, message
              assert_equal "tool_1", message.tool_call_id
              assert_equal :bash, message.name
              assert_equal({ command: "ls -la" }, message.arguments)
            end

            test "from_hash dispatches tool_execution_start type" do
              message = Message.from_hash({
                type: "tool_execution_start",
                toolCallId: "123",
                toolName: "bash",
                args: {},
              })

              assert_kind_of Messages::ToolExecutionStartMessage, message
            end

            test "from_hash dispatches tool_execution_update type" do
              message = Message.from_hash({
                type: "tool_execution_update",
                toolCallId: "123",
                toolName: "bash",
                args: {},
                partialResult: {},
              })

              assert_kind_of Messages::ToolExecutionUpdateMessage, message
            end

            test "from_hash dispatches tool_execution_end type" do
              message = Message.from_hash({
                type: "tool_execution_end",
                toolCallId: "123",
                toolName: "bash",
                result: { content: [{ type: "text", text: "output" }] },
                isError: false,
              })

              assert_kind_of Messages::ToolExecutionEndMessage, message
            end

            test "from_hash dispatches unknown message_update sub-type" do
              message = Message.from_hash({
                type: "message_update",
                assistantMessageEvent: { type: "new_event_type" },
              })

              assert_kind_of Messages::UnknownMessage, message
            end
          end
        end
      end
    end
  end
end
