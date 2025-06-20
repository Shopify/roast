# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class NullStrategyTest < ActiveSupport::TestCase
      def setup
        @strategy = NullStrategy.new
      end

      test "should_retry? always returns false" do
        error = StandardError.new("any error")
        refute @strategy.should_retry?(error, 1)
        refute @strategy.should_retry?(error, 100)
      end

      test "calculate_delay always returns 0" do
        assert_equal 0, @strategy.calculate_delay(1)
        assert_equal 0, @strategy.calculate_delay(100)
      end
    end
  end
end
