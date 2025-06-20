# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class LinearBackoffStrategyTest < ActiveSupport::TestCase
      def setup
        @strategy = LinearBackoffStrategy.new({
          "base_delay" => 1.0,
          "increment" => 0.5,
          "max_delay" => 5.0,
        })
      end

      test "calculate_delay increases linearly" do
        assert_equal 1.0, @strategy.calculate_delay(1)
        assert_equal 1.5, @strategy.calculate_delay(2)
        assert_equal 2.0, @strategy.calculate_delay(3)
        assert_equal 2.5, @strategy.calculate_delay(4)
      end

      test "calculate_delay respects max_delay" do
        assert_equal 3.0, @strategy.calculate_delay(5)
        assert_equal 3.5, @strategy.calculate_delay(6)
        assert_equal 4.0, @strategy.calculate_delay(7)
        assert_equal 4.5, @strategy.calculate_delay(8)
        assert_equal 5.0, @strategy.calculate_delay(9)  # capped at max_delay
        assert_equal 5.0, @strategy.calculate_delay(10) # still capped
      end

      test "defaults increment to base_delay" do
        strategy = LinearBackoffStrategy.new({ "base_delay" => 2.0 })
        assert_equal 2.0, strategy.increment
        assert_equal 2.0, strategy.calculate_delay(1)
        assert_equal 4.0, strategy.calculate_delay(2)
        assert_equal 6.0, strategy.calculate_delay(3)
      end
    end
  end
end
