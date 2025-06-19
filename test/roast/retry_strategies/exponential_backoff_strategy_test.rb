# frozen_string_literal: true

require "test_helper"

module Roast
  module RetryStrategies
    class ExponentialBackoffStrategyTest < ActiveSupport::TestCase
      setup do
        @strategy = ExponentialBackoffStrategy.new
      end

      test "calculates exponential delays" do
        assert_equal 1, @strategy.calculate(1, base_delay: 1, max_delay: 60)
        assert_equal 2, @strategy.calculate(2, base_delay: 1, max_delay: 60)
        assert_equal 4, @strategy.calculate(3, base_delay: 1, max_delay: 60)
        assert_equal 8, @strategy.calculate(4, base_delay: 1, max_delay: 60)
        assert_equal 16, @strategy.calculate(5, base_delay: 1, max_delay: 60)
      end

      test "respects max_delay limit" do
        assert_equal 60, @strategy.calculate(10, base_delay: 1, max_delay: 60)
        assert_equal 60, @strategy.calculate(20, base_delay: 1, max_delay: 60)
      end

      test "uses custom base_delay" do
        assert_equal 2, @strategy.calculate(1, base_delay: 2, max_delay: 60)
        assert_equal 4, @strategy.calculate(2, base_delay: 2, max_delay: 60)
        assert_equal 8, @strategy.calculate(3, base_delay: 2, max_delay: 60)
      end
    end
  end
end
