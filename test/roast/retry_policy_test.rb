# frozen_string_literal: true

require "test_helper"

module Roast
  class RetryPolicyTest < ActiveSupport::TestCase
    setup do
      @strategy = RetryStrategies::ExponentialBackoffStrategy.new
      @matcher = Matchers::AlwaysRetryMatcher.new
      @handler = Handlers::BaseHandler.new
    end

    test "initializes with default values" do
      policy = RetryPolicy.new(strategy: @strategy)

      assert_equal @strategy, policy.strategy
      assert_equal 3, policy.max_attempts
      assert_equal 1, policy.base_delay
      assert_equal 60, policy.max_delay
      assert_equal false, policy.jitter
      assert_kind_of Matchers::AlwaysRetryMatcher, policy.matcher
      assert_empty policy.handlers
    end

    test "initializes with custom values" do
      handlers = [@handler]
      policy = RetryPolicy.new(
        strategy: @strategy,
        max_attempts: 5,
        matcher: @matcher,
        handlers: handlers,
        base_delay: 2,
        max_delay: 120,
        jitter: true
      )

      assert_equal @strategy, policy.strategy
      assert_equal 5, policy.max_attempts
      assert_equal @matcher, policy.matcher
      assert_equal handlers, policy.handlers
      assert_equal 2, policy.base_delay
      assert_equal 120, policy.max_delay
      assert_equal true, policy.jitter
    end

    test "should_retry? returns true when within max attempts and matcher matches" do
      policy = RetryPolicy.new(strategy: @strategy, max_attempts: 3)
      error = StandardError.new

      assert policy.should_retry?(error, 1)
      assert policy.should_retry?(error, 2)
      refute policy.should_retry?(error, 3)
    end

    test "should_retry? returns false when matcher does not match" do
      matcher = Matchers::ErrorTypeMatcher.new(ArgumentError)
      policy = RetryPolicy.new(strategy: @strategy, matcher: matcher)
      error = StandardError.new

      refute policy.should_retry?(error, 1)
    end

    test "delay_for delegates to strategy" do
      strategy = mock
      strategy.expects(:calculate).with(2, base_delay: 1, max_delay: 60).returns(4)
      
      policy = RetryPolicy.new(strategy: strategy)
      
      assert_equal 4, policy.delay_for(2)
    end

    test "delay_for adds jitter when enabled" do
      strategy = mock
      strategy.expects(:calculate).returns(10).at_least_once
      
      policy = RetryPolicy.new(strategy: strategy, jitter: true)
      
      delays = 10.times.map { policy.delay_for(1) }
      
      # Verify jitter is applied - delays should vary
      assert delays.uniq.size > 1
      # Verify delays are within expected range (10 ± 10%)
      assert delays.all? { |d| d >= 9 && d <= 11 }
    end
  end
end