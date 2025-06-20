# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class ExponentialBackoffStrategyTest < ActiveSupport::TestCase
      def setup
        @strategy = ExponentialBackoffStrategy.new({
          "base_delay" => 1.0,
          "max_delay" => 30.0,
          "multiplier" => 2.0,
          "jitter" => true,
        })
      end

      test "calculate_delay increases exponentially" do
        # Without jitter for predictable testing
        strategy = ExponentialBackoffStrategy.new({
          "base_delay" => 1.0,
          "multiplier" => 2.0,
          "jitter" => false,
        })

        assert_equal 1.0, strategy.calculate_delay(1)
        assert_equal 2.0, strategy.calculate_delay(2)
        assert_equal 4.0, strategy.calculate_delay(3)
        assert_equal 8.0, strategy.calculate_delay(4)
      end

      test "calculate_delay respects max_delay" do
        strategy = ExponentialBackoffStrategy.new({
          "base_delay" => 1.0,
          "max_delay" => 5.0,
          "multiplier" => 2.0,
          "jitter" => false,
        })

        assert_equal 1.0, strategy.calculate_delay(1)
        assert_equal 2.0, strategy.calculate_delay(2)
        assert_equal 4.0, strategy.calculate_delay(3)
        assert_equal 5.0, strategy.calculate_delay(4) # capped at max_delay
        assert_equal 5.0, strategy.calculate_delay(5) # still capped
      end

      test "calculate_delay adds jitter when enabled" do
        delays = 10.times.map { @strategy.calculate_delay(3) }

        # All delays should be different due to jitter
        assert delays.uniq.size > 1

        # All delays should be within expected range
        expected_base = 4.0 # 1.0 * 2^(3-1)
        expected_max = expected_base * 1.25 # 25% jitter

        delays.each do |delay|
          assert delay >= expected_base
          assert delay <= expected_max
        end
      end

      test "defaults to jitter enabled and multiplier 2.0" do
        strategy = ExponentialBackoffStrategy.new
        assert_equal true, strategy.jitter
        assert_equal 2.0, strategy.multiplier
      end
    end
  end
end
