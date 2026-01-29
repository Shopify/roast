# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ResultMessageTest < ActiveSupport::TestCase
              test "initialize with success subtype sets success to true" do
                hash = { subtype: "success", result: "Task completed" }
                message = ResultMessage.new(type: :result, hash:)

                assert message.success
                assert_equal "Task completed", message.content
              end

              test "initialize with error subtype sets content to empty string when no result" do
                hash = { subtype: "error", error: { message: "Something went wrong" } }
                message = ResultMessage.new(type: :result, hash:)

                refute message.success
                assert_equal "", message.content
              end

              test "initialize with is_error sets content from result" do
                hash = { is_error: true, result: "Error result" }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal "Error result", message.content
              end

              test "initialize with is_error and no result sets content to empty string" do
                hash = { is_error: true }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal "", message.content
              end

              test "initialize sets content from result field" do
                hash = { result: "Test result" }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal "Test result", message.content
              end

              test "initialize sets content to empty string when no result" do
                hash = {}
                message = ResultMessage.new(type: :result, hash:)

                assert_equal "", message.content
              end

              test "initialize sets success from hash" do
                hash = { success: true }
                message = ResultMessage.new(type: :result, hash:)

                assert message.success
              end

              test "initialize creates stats object" do
                hash = {}
                message = ResultMessage.new(type: :result, hash:)

                assert_kind_of Stats, message.stats
              end

              test "initialize sets duration_ms in stats" do
                hash = { duration_ms: 1500 }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal 1500, message.stats.duration_ms
              end

              test "initialize sets num_turns in stats" do
                hash = { num_turns: 3 }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal 3, message.stats.num_turns
              end

              test "initialize sets total_cost_usd in stats usage" do
                hash = { total_cost_usd: 0.05 }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal 0.05, message.stats.usage.cost_usd
              end

              test "initialize processes modelUsage into stats" do
                hash = {
                  modelUsage: {
                    "claude-3-opus" => {
                      inputTokens: 100,
                      outputTokens: 50,
                      costUSD: 0.03,
                    },
                  },
                }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal 1, message.stats.model_usage.size
                assert_equal 100, message.stats.model_usage["claude-3-opus"].input_tokens
                assert_equal 50, message.stats.model_usage["claude-3-opus"].output_tokens
                assert_equal 0.03, message.stats.model_usage["claude-3-opus"].cost_usd
              end

              test "initialize aggregates token usage across models" do
                hash = {
                  modelUsage: {
                    "model-a" => { inputTokens: 100, outputTokens: 50, costUSD: 0.02 },
                    "model-b" => { inputTokens: 200, outputTokens: 75, costUSD: 0.03 },
                  },
                }
                message = ResultMessage.new(type: :result, hash:)

                assert_equal 300, message.stats.usage.input_tokens
                assert_equal 125, message.stats.usage.output_tokens
              end

              test "initialize removes ignored fields from hash" do
                hash = {
                  duration_api_ms: 1000,
                  permission_denials: [],
                  usage: {},
                  uuid: "abc-123",
                }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:duration_api_ms)
                refute hash.key?(:permission_denials)
                refute hash.key?(:usage)
                refute hash.key?(:uuid)
              end

              test "initialize removes subtype from hash" do
                hash = { subtype: "success" }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:subtype)
              end

              test "initialize removes result from hash" do
                hash = { result: "done" }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:result)
              end

              test "initialize removes success from hash" do
                hash = { success: true }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:success)
              end

              test "initialize removes error from hash when is_error is true" do
                hash = { is_error: true, error: { message: "test" } }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:error)
              end

              test "initialize removes duration_ms from hash" do
                hash = { duration_ms: 100 }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:duration_ms)
              end

              test "initialize removes num_turns from hash" do
                hash = { num_turns: 1 }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:num_turns)
              end

              test "initialize removes modelUsage from hash" do
                hash = { modelUsage: {} }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:modelUsage)
              end

              test "initialize removes total_cost_usd from hash" do
                hash = { total_cost_usd: 0.01 }
                ResultMessage.new(type: :result, hash:)

                refute hash.key?(:total_cost_usd)
              end
            end
          end
        end
      end
    end
  end
end
