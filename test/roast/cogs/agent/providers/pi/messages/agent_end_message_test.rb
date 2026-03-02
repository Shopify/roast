# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class AgentEndMessageTest < ActiveSupport::TestCase
              test "initialize extracts messages array" do
                hash = {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                    { role: "assistant", content: [{ type: "text", text: "Hi!" }] },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal 2, message.messages.length
              end

              test "initialize defaults messages to empty array" do
                message = AgentEndMessage.new(type: "agent_end", hash: {})

                assert_equal [], message.messages
              end

              test "initialize removes messages from hash" do
                hash = { messages: [] }
                AgentEndMessage.new(type: "agent_end", hash:)

                refute hash.key?(:messages)
              end

              test "final_response extracts text from last assistant message" do
                hash = {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                    { role: "assistant", content: [{ type: "text", text: "Hi there!" }] },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "Hi there!", message.final_response
              end

              test "final_response returns last assistant message when multiple exist" do
                hash = {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                    { role: "assistant", content: [{ type: "toolCall", name: "read" }] },
                    { role: "assistant", content: [{ type: "text", text: "Final answer" }] },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "Final answer", message.final_response
              end

              test "final_response joins multiple text blocks" do
                hash = {
                  messages: [
                    {
                      role: "assistant",
                      content: [
                        { type: "text", text: "Part 1" },
                        { type: "text", text: " Part 2" },
                      ],
                    },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "Part 1 Part 2", message.final_response
              end

              test "final_response ignores non-text content" do
                hash = {
                  messages: [
                    {
                      role: "assistant",
                      content: [
                        { type: "toolCall", name: "read", arguments: {} },
                        { type: "text", text: "Done" },
                      ],
                    },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "Done", message.final_response
              end

              test "final_response returns empty string when no assistant messages" do
                hash = {
                  messages: [
                    { role: "user", content: [{ type: "text", text: "Hello" }] },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "", message.final_response
              end

              test "final_response returns empty string when no messages" do
                message = AgentEndMessage.new(type: "agent_end", hash: {})

                assert_equal "", message.final_response
              end

              test "model extracts model from last assistant message" do
                hash = {
                  messages: [
                    { role: "assistant", model: "claude-opus-4-6", content: [] },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal "claude-opus-4-6", message.model
              end

              test "model returns nil when no assistant messages" do
                message = AgentEndMessage.new(type: "agent_end", hash: {})

                assert_nil message.model
              end

              test "usage extracts usage from last assistant message" do
                hash = {
                  messages: [
                    {
                      role: "assistant",
                      usage: { input: 10, output: 5, cost: { total: 0.001 } },
                      content: [],
                    },
                  ],
                }
                message = AgentEndMessage.new(type: "agent_end", hash:)

                assert_equal 10, message.usage[:input]
                assert_equal 5, message.usage[:output]
              end

              test "usage returns nil when no assistant messages" do
                message = AgentEndMessage.new(type: "agent_end", hash: {})

                assert_nil message.usage
              end
            end
          end
        end
      end
    end
  end
end
