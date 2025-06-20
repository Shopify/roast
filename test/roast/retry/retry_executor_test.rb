# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class RetryExecutorTest < ActiveSupport::TestCase
      def setup
        @executor = RetryExecutor.new
      end

      test "executes block successfully on first try" do
        strategy = mock_strategy(should_retry: false)

        result = @executor.execute(strategy) { "success" }

        assert_equal "success", result
      end

      test "retries on failure and eventually succeeds" do
        attempts = 0
        strategy = mock_strategy(
          should_retry: [true, true, false],
          calculate_delay: [0.01, 0.01],
        )

        result = @executor.execute(strategy) do
          attempts += 1
          raise StandardError, "failed" if attempts < 3

          "success after #{attempts} attempts"
        end

        assert_equal "success after 3 attempts", result
        assert_equal 3, attempts
      end

      test "raises error when retries exhausted" do
        strategy = mock_strategy(should_retry: false)

        assert_raises(StandardError, "permanent failure") do
          @executor.execute(strategy) { raise StandardError, "permanent failure" }
        end
      end

      test "logs retry attempts" do
        # Test logging happens via ActiveSupport notifications instead
        events = []
        ActiveSupport::Notifications.subscribe("roast.retry.attempt") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event.payload
        end

        strategy = mock_strategy(
          should_retry: [true, false],
          calculate_delay: [0.01],
        )

        assert_raises(StandardError) do
          @executor.execute(strategy) { raise StandardError, "test error" }
        end

        assert_equal(1, events.size)
        assert_equal(1, events[0][:attempt])
        assert_equal("StandardError", events[0][:error])
        assert_equal("test error", events[0][:message])
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.retry.attempt")
      end

      test "sends instrumentation events" do
        events = []
        ActiveSupport::Notifications.subscribe("roast.retry.attempt") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event.payload
        end

        strategy = mock_strategy(
          should_retry: [true, false],
          calculate_delay: [0.01],
        )

        assert_raises(StandardError) do
          @executor.execute(strategy) { raise StandardError, "test error" }
        end

        assert_equal(1, events.size)
        assert_equal(1, events[0][:attempt])
        assert_equal("StandardError", events[0][:error])
        assert_equal("test error", events[0][:message])
        assert_equal(0.01, events[0][:delay])
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.retry.attempt")
      end

      test "sleeps for calculated delay between retries" do
        strategy = mock_strategy(
          should_retry: [true, false],
          calculate_delay: [0.1],
        )

        start_time = Time.now
        assert_raises(StandardError) do
          @executor.execute(strategy) { raise StandardError, "test" }
        end
        elapsed = Time.now - start_time

        assert elapsed >= 0.1, "Should have slept for at least 0.1 seconds"
      end

      private

      def mock_strategy(should_retry:, calculate_delay: nil)
        strategy = Object.new

        # Handle should_retry? with array of return values
        retry_returns = Array(should_retry)
        retry_index = 0
        strategy.define_singleton_method(:should_retry?) do |_error, _attempt|
          result = retry_returns[retry_index] || false
          retry_index += 1
          result
        end

        # Handle calculate_delay with array of return values
        if calculate_delay
          delay_returns = Array(calculate_delay)
          delay_index = 0
          strategy.define_singleton_method(:calculate_delay) do |_attempt|
            result = delay_returns[delay_index] || 0
            delay_index += 1
            result
          end
        end

        strategy
      end
    end
  end
end
