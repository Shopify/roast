# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class RetryStrategyTest < ActiveSupport::TestCase
      def setup
        @strategy = RetryStrategy.new({
          "max_attempts" => 3,
          "base_delay" => 1.0,
          "max_delay" => 30.0,
        })
      end

      test "should_retry? returns true for retryable errors within max attempts" do
        error = Net::ReadTimeout.new("timeout")
        assert @strategy.should_retry?(error, 1)
        assert @strategy.should_retry?(error, 2)
        assert @strategy.should_retry?(error, 3)
        refute @strategy.should_retry?(error, 4)
      end

      test "should_retry? returns true for rate limit errors" do
        error = StandardError.new("rate limit exceeded")
        assert @strategy.should_retry?(error, 1)
      end

      test "should_retry? returns true for temporarily unavailable errors" do
        error = StandardError.new("service temporarily unavailable")
        assert @strategy.should_retry?(error, 1)
      end

      test "should_retry? returns true for server errors" do
        error = StandardError.new("internal server error")
        assert @strategy.should_retry?(error, 1)
      end

      test "should_retry? returns false for non-retryable errors" do
        error = StandardError.new("invalid argument")
        refute @strategy.should_retry?(error, 1)
      end

      test "should_retry? returns false when max attempts exceeded" do
        error = Net::ReadTimeout.new("timeout")
        refute @strategy.should_retry?(error, 4)
      end

      test "calculate_delay raises NotImplementedError" do
        assert_raises(NotImplementedError) do
          @strategy.calculate_delay(1)
        end
      end

      test "configuration defaults" do
        strategy = RetryStrategy.new
        assert_equal 3, strategy.max_attempts
        assert_equal 1.0, strategy.base_delay
        assert_equal 60.0, strategy.max_delay
      end
    end
  end
end
