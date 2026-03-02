# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolCallEndMessageTest < ActiveSupport::TestCase
              test "extracts tool call details from assistantMessageEvent" do
                message = ToolCallEndMessage.new(
                  type: :toolcall_end,
                  hash: {
                    assistantMessageEvent: {
                      type: "toolcall_end",
                      toolCall: { id: "tool_abc", name: "bash", arguments: { command: "echo hi" } },
                    },
                  },
                )

                assert_equal "tool_abc", message.tool_call_id
                assert_equal :bash, message.name
                assert_equal({ command: "echo hi" }, message.arguments)
              end

              test "name defaults to :unknown when not present" do
                message = ToolCallEndMessage.new(
                  type: :toolcall_end,
                  hash: {
                    assistantMessageEvent: {
                      type: "toolcall_end",
                      toolCall: { id: "tool_abc" },
                    },
                  },
                )

                assert_equal :unknown, message.name
              end

              test "format returns tool use description" do
                message = ToolCallEndMessage.new(
                  type: :toolcall_end,
                  hash: {
                    assistantMessageEvent: {
                      type: "toolcall_end",
                      toolCall: { id: "tool_1", name: "bash", arguments: { command: "ls -la" } },
                    },
                  },
                )

                context = PiInvocation::Context.new
                formatted = message.format(context)
                assert_equal "BASH ls -la", formatted
              end

              test "format returns read description for read tool" do
                message = ToolCallEndMessage.new(
                  type: :toolcall_end,
                  hash: {
                    assistantMessageEvent: {
                      type: "toolcall_end",
                      toolCall: { id: "tool_1", name: "read", arguments: { path: "/tmp/file.rb" } },
                    },
                  },
                )

                context = PiInvocation::Context.new
                formatted = message.format(context)
                assert_equal "READ /tmp/file.rb", formatted
              end
            end
          end
        end
      end
    end
  end
end
