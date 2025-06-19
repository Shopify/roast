# frozen_string_literal: true

require "test_helper"

module Roast
  class RetryableTest < ActiveSupport::TestCase
    setup do
      @strategy = RetryStrategies::FixedDelayStrategy.new
      @policy = RetryPolicy.new(strategy: @strategy, base_delay: 0.01)
      @metrics = Metrics::RetryMetrics.new
    end

    test "executes block successfully on first attempt" do
      retryable = Retryable.new(policy: @policy, metrics: @metrics)
      
      result = retryable.execute { "success" }
      
      assert_equal "success", result
      assert_equal 1, @metrics.attempts
      assert_equal 0, @metrics.retries
      assert_equal 1, @metrics.successes
      assert_equal 0, @metrics.failures
    end

    test "retries on failure and eventually succeeds" do
      attempts = 0
      retryable = Retryable.new(policy: @policy, metrics: @metrics)
      
      result = retryable.execute do
        attempts += 1
        raise StandardError, "Failed" if attempts < 3
        "success"
      end
      
      assert_equal "success", result
      assert_equal 3, @metrics.attempts
      assert_equal 2, @metrics.retries
      assert_equal 1, @metrics.successes
      assert_equal 0, @metrics.failures
    end

    test "raises error after max attempts" do
      retryable = Retryable.new(policy: @policy, metrics: @metrics)
      
      error = assert_raises(StandardError) do
        retryable.execute { raise StandardError, "Always fails" }
      end
      
      assert_equal "Always fails", error.message
      assert_equal 3, @metrics.attempts
      assert_equal 2, @metrics.retries
      assert_equal 0, @metrics.successes
      assert_equal 1, @metrics.failures
    end

    test "notifies handlers at appropriate times" do
      handler = mock
      handler.expects(:before_attempt).with(1).once
      handler.expects(:before_attempt).with(2).once
      handler.expects(:on_retry).with(instance_of(StandardError), 1).once
      handler.expects(:on_success).with(2).once
      handler.expects(:on_failure).never
      
      policy = RetryPolicy.new(
        strategy: @strategy,
        handlers: [handler],
        base_delay: 0.01
      )
      retryable = Retryable.new(policy: policy)
      
      attempts = 0
      retryable.execute do
        attempts += 1
        raise StandardError, "Failed" if attempts < 2
        "success"
      end
    end

    test "respects retry policy matcher" do
      matcher = Matchers::ErrorTypeMatcher.new(ArgumentError)
      policy = RetryPolicy.new(strategy: @strategy, matcher: matcher)
      retryable = Retryable.new(policy: policy, metrics: @metrics)
      
      # StandardError should not be retried
      assert_raises(StandardError) do
        retryable.execute { raise StandardError, "Not retryable" }
      end
      
      assert_equal 1, @metrics.attempts
      assert_equal 0, @metrics.retries
    end

    test "sleeps between retries" do
      strategy = mock
      strategy.expects(:calculate).returns(0.1)
      
      policy = RetryPolicy.new(strategy: strategy)
      retryable = Retryable.new(policy: policy)
      
      start_time = Time.now
      attempts = 0
      
      retryable.execute do
        attempts += 1
        raise StandardError if attempts < 2
        "success"
      end
      
      elapsed = Time.now - start_time
      assert elapsed >= 0.1, "Should have slept for at least 0.1 seconds"
    end

    test "tracks duration in metrics" do
      retryable = Retryable.new(policy: @policy, metrics: @metrics)
      
      retryable.execute do
        sleep 0.01
        "success"
      end
      
      assert @metrics.average_duration >= 0.01
      assert_equal 100.0, @metrics.success_rate
    end
  end
end