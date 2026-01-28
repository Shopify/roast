# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class StatsTest < ActiveSupport::TestCase
        def setup
          @stats = Stats.new
        end

        test "initialize creates empty usage" do
          assert_not_nil @stats.usage
        end

        test "initialize creates empty model_usage hash" do
          assert_equal({}, @stats.model_usage)
        end

        test "to_s shows NO_VALUE for nil duration" do
          output = @stats.to_s

          assert_match(/Duration: ---/, output)
        end

        test "to_s shows NO_VALUE for nil turns" do
          output = @stats.to_s

          assert_match(/Turns: ---/, output)
        end

        test "to_s shows NO_VALUE for nil cost" do
          output = @stats.to_s

          assert_match(/Cost \(USD\): \$---/, output)
        end

        test "to_s formats duration when present" do
          @stats.duration_ms = 5000

          output = @stats.to_s

          assert_match(/Duration: 5 seconds/, output)
        end

        test "to_s formats turns when present" do
          @stats.num_turns = 3

          output = @stats.to_s

          assert_match(/Turns: 3/, output)
        end

        test "to_s formats cost when present" do
          @stats.usage.cost_usd = 0.123456

          output = @stats.to_s

          assert_match(/Cost \(USD\): \$0\.123456/, output)
        end

        test "to_s includes model usage when present" do
          model_usage = Usage.new
          model_usage.input_tokens = 1000
          model_usage.output_tokens = 500
          @stats.model_usage["claude-3-opus"] = model_usage

          output = @stats.to_s

          assert_match(/Tokens \(claude-3-opus\):/, output)
          assert_match(/in, 500 out/, output)
        end

        test "to_s shows NO_VALUE for model with nil tokens" do
          model_usage = Usage.new
          @stats.model_usage["test-model"] = model_usage

          output = @stats.to_s

          assert_match(/Tokens \(test-model\): --- in, --- out/, output)
        end

        test "to_s includes multiple models" do
          model1 = Usage.new
          model1.input_tokens = 1000
          model1.output_tokens = 500

          model2 = Usage.new
          model2.input_tokens = 2000
          model2.output_tokens = 1000

          @stats.model_usage["model1"] = model1
          @stats.model_usage["model2"] = model2

          output = @stats.to_s

          assert_match(/Tokens \(model1\):/, output)
          assert_match(/Tokens \(model2\):/, output)
        end

        test "to_s formats complete stats" do
          @stats.duration_ms = 5000
          @stats.num_turns = 3
          @stats.usage.cost_usd = 0.05

          model_usage = Usage.new
          model_usage.input_tokens = 1000
          model_usage.output_tokens = 500
          @stats.model_usage["claude-3-opus"] = model_usage

          output = @stats.to_s

          assert_match(/Turns: 3/, output)
          assert_match(/Duration: 5 seconds/, output)
          assert_match(/Cost \(USD\): \$0\.05/, output)
          assert_match(/Tokens \(claude-3-opus\):/, output)
        end
      end
    end
  end
end
