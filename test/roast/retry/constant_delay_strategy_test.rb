# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class ConstantDelayStrategyTest < ActiveSupport::TestCase
      def setup
        @strategy = ConstantDelayStrategy.new({ "base_delay" => 2.0 })
      end

      test "calculate_delay returns constant value" do
        assert_equal 2.0, @strategy.calculate_delay(1)
        assert_equal 2.0, @strategy.calculate_delay(2)
        assert_equal 2.0, @strategy.calculate_delay(3)
        assert_equal 2.0, @strategy.calculate_delay(10)
      end

      test "uses default base_delay if not specified" do
        strategy = ConstantDelayStrategy.new
        assert_equal 1.0, strategy.calculate_delay(1)
      end
    end
  end
end
