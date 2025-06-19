# frozen_string_literal: true

require "test_helper"

module Roast
  module RetryStrategies
    class FixedDelayStrategyTest < ActiveSupport::TestCase
      setup do
        @strategy = FixedDelayStrategy.new
      end

      test "returns fixed delay regardless of attempt" do
        assert_equal 1, @strategy.calculate(1, base_delay: 1, max_delay: 60)
        assert_equal 1, @strategy.calculate(2, base_delay: 1, max_delay: 60)
        assert_equal 1, @strategy.calculate(3, base_delay: 1, max_delay: 60)
        assert_equal 1, @strategy.calculate(10, base_delay: 1, max_delay: 60)
      end

      test "uses custom base_delay" do
        assert_equal 5, @strategy.calculate(1, base_delay: 5, max_delay: 60)
        assert_equal 5, @strategy.calculate(2, base_delay: 5, max_delay: 60)
        assert_equal 5, @strategy.calculate(3, base_delay: 5, max_delay: 60)
      end

      test "ignores max_delay" do
        assert_equal 100, @strategy.calculate(1, base_delay: 100, max_delay: 60)
      end
    end
  end
end