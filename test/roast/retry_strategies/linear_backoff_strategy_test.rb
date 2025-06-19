# frozen_string_literal: true

require "test_helper"

module Roast
  module RetryStrategies
    class LinearBackoffStrategyTest < ActiveSupport::TestCase
      setup do
        @strategy = LinearBackoffStrategy.new
      end

      test "calculates linear delays" do
        assert_equal 1, @strategy.calculate(1, base_delay: 1, max_delay: 60)
        assert_equal 2, @strategy.calculate(2, base_delay: 1, max_delay: 60)
        assert_equal 3, @strategy.calculate(3, base_delay: 1, max_delay: 60)
        assert_equal 4, @strategy.calculate(4, base_delay: 1, max_delay: 60)
        assert_equal 5, @strategy.calculate(5, base_delay: 1, max_delay: 60)
      end

      test "respects max_delay limit" do
        assert_equal 60, @strategy.calculate(100, base_delay: 1, max_delay: 60)
        assert_equal 60, @strategy.calculate(200, base_delay: 1, max_delay: 60)
      end

      test "uses custom base_delay" do
        assert_equal 3, @strategy.calculate(1, base_delay: 3, max_delay: 60)
        assert_equal 6, @strategy.calculate(2, base_delay: 3, max_delay: 60)
        assert_equal 9, @strategy.calculate(3, base_delay: 3, max_delay: 60)
      end
    end
  end
end