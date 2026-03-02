# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class TurnEndMessageTest < ActiveSupport::TestCase
              test "initialize extracts message" do
                hash = {
                  message: { role: "assistant", model: "claude-opus-4-6", content: [] },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal "assistant", message.message[:role]
              end

              test "initialize extracts tool_results" do
                hash = {
                  message: {},
                  toolResults: [{ id: "123", content: "ok" }],
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal 1, message.tool_results.length
              end

              test "initialize defaults tool_results to empty array" do
                hash = { message: {} }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal [], message.tool_results
              end

              test "initialize removes parsed fields from hash" do
                hash = { message: {}, toolResults: [] }
                TurnEndMessage.new(type: "turn_end", hash:)

                refute hash.key?(:message)
                refute hash.key?(:toolResults)
              end

              test "model returns model from message" do
                hash = {
                  message: { model: "claude-opus-4-6" },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal "claude-opus-4-6", message.model
              end

              test "model returns nil when message is nil" do
                message = TurnEndMessage.new(type: "turn_end", hash: {})

                assert_nil message.model
              end

              test "usage returns usage from message" do
                hash = {
                  message: {
                    usage: { input: 100, output: 50, cost: { total: 0.01 } },
                  },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal 100, message.usage[:input]
                assert_equal 50, message.usage[:output]
              end

              test "usage returns nil when message is nil" do
                message = TurnEndMessage.new(type: "turn_end", hash: {})

                assert_nil message.usage
              end

              test "content returns content array from message" do
                hash = {
                  message: {
                    content: [{ type: "text", text: "Hello" }],
                  },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal 1, message.content.length
                assert_equal "text", message.content.first[:type]
              end

              test "content returns empty array when message is nil" do
                message = TurnEndMessage.new(type: "turn_end", hash: {})

                assert_equal [], message.content
              end

              test "stop_reason returns stopReason from message" do
                hash = {
                  message: { stopReason: "stop" },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_equal "stop", message.stop_reason
              end

              test "stop_reason returns nil when message is nil" do
                message = TurnEndMessage.new(type: "turn_end", hash: {})

                assert_nil message.stop_reason
              end

              # format tests

              test "format returns summary with model and usage" do
                hash = {
                  message: {
                    model: "claude-opus-4-6",
                    usage: { input: 100, output: 50, cost: { total: 0.025 } },
                  },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                result = message.format

                assert_includes result, "turn end"
                assert_includes result, "claude-opus-4-6"
                assert_includes result, "100 in"
                assert_includes result, "50 out"
                assert_includes result, "$0.025000"
              end

              test "format returns nil when no usage" do
                hash = { message: { model: "test" } }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_nil message.format
              end

              test "format returns nil when message is nil" do
                message = TurnEndMessage.new(type: "turn_end", hash: {})

                assert_nil message.format
              end

              test "format shows unknown model when model is nil" do
                hash = {
                  message: {
                    usage: { input: 10, output: 5, cost: { total: 0.001 } },
                  },
                }
                message = TurnEndMessage.new(type: "turn_end", hash:)

                assert_includes message.format, "unknown"
              end
            end
          end
        end
      end
    end
  end
end
