# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class UsageTest < ActiveSupport::TestCase
        test "+ sums input_tokens" do
          a = Usage.new
          a.input_tokens = 100
          b = Usage.new
          b.input_tokens = 200

          result = a + b

          assert_equal 300, result.input_tokens
        end

        test "+ sums output_tokens" do
          a = Usage.new
          a.output_tokens = 50
          b = Usage.new
          b.output_tokens = 75

          result = a + b

          assert_equal 125, result.output_tokens
        end

        test "+ sums cost_usd" do
          a = Usage.new
          a.cost_usd = 0.01
          b = Usage.new
          b.cost_usd = 0.02

          result = a + b

          assert_in_delta 0.03, result.cost_usd
        end

        test "+ treats nil as zero when other is non-nil" do
          a = Usage.new
          a.input_tokens = 100
          b = Usage.new

          result = a + b

          assert_equal 100, result.input_tokens
          assert_nil result.output_tokens
        end

        test "+ returns nil when both values are nil" do
          a = Usage.new
          b = Usage.new

          result = a + b

          assert_nil result.input_tokens
          assert_nil result.output_tokens
          assert_nil result.cost_usd
        end

        test "+ does not mutate operands" do
          a = Usage.new
          a.input_tokens = 100
          b = Usage.new
          b.input_tokens = 200

          _ = a + b

          assert_equal 100, a.input_tokens
          assert_equal 200, b.input_tokens
        end
      end
    end
  end
end
