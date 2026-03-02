# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class AgentEndMessageTest < ActiveSupport::TestCase
              test "extracts response from last assistant message" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      { role: "user", content: [{ type: "text", text: "hello" }] },
                      { role: "assistant", content: [{ type: "text", text: "Hi there!" }], model: "test-model", usage: { input: 5, output: 10, cost: { total: 0.001 } } },
                    ],
                  },
                )

                assert_equal "Hi there!", message.response
              end

              test "joins multiple text content blocks" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      {
                        role: "assistant",
                        content: [
                          { type: "thinking", thinking: "Let me think..." },
                          { type: "text", text: "Part one. " },
                          { type: "text", text: "Part two." },
                        ],
                        model: "test-model",
                        usage: { input: 5, output: 10, cost: { total: 0.001 } },
                      },
                    ],
                  },
                )

                assert_equal "Part one. Part two.", message.response
              end

              test "returns empty string when no assistant messages" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      { role: "user", content: [{ type: "text", text: "hello" }] },
                    ],
                  },
                )

                assert_equal "", message.response
              end

              test "success is true by default" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: { messages: [] },
                )

                assert message.success
              end

              test "computes aggregate stats from assistant messages" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      {
                        role: "assistant",
                        model: "claude-sonnet",
                        content: [{ type: "text", text: "response 1" }],
                        usage: { input: 100, output: 50, cost: { total: 0.01 } },
                      },
                      { role: "user", content: [{ type: "text", text: "followup" }] },
                      {
                        role: "assistant",
                        model: "claude-sonnet",
                        content: [{ type: "text", text: "response 2" }],
                        usage: { input: 200, output: 80, cost: { total: 0.02 } },
                      },
                    ],
                  },
                )

                stats = message.stats
                assert_equal 300, stats.usage.input_tokens
                assert_equal 130, stats.usage.output_tokens
                assert_in_delta 0.03, stats.usage.cost_usd

                model_usage = stats.model_usage["claude-sonnet"]
                assert_not_nil model_usage
                assert_equal 300, model_usage.input_tokens
                assert_equal 130, model_usage.output_tokens
              end

              test "computes per-model stats for multiple models" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      {
                        role: "assistant",
                        model: "model-a",
                        content: [{ type: "text", text: "" }],
                        usage: { input: 100, output: 50, cost: { total: 0.01 } },
                      },
                      {
                        role: "assistant",
                        model: "model-b",
                        content: [{ type: "text", text: "final" }],
                        usage: { input: 200, output: 80, cost: { total: 0.02 } },
                      },
                    ],
                  },
                )

                stats = message.stats
                assert_equal 2, stats.model_usage.size
                assert_equal 100, stats.model_usage["model-a"].input_tokens
                assert_equal 200, stats.model_usage["model-b"].input_tokens
              end

              test "handles assistant messages without usage data" do
                message = AgentEndMessage.new(
                  type: :agent_end,
                  hash: {
                    messages: [
                      { role: "assistant", content: [{ type: "text", text: "hi" }] },
                    ],
                  },
                )

                assert_equal "hi", message.response
                assert message.stats.model_usage.empty?
              end
            end
          end
        end
      end
    end
  end
end
