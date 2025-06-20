# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class IntegrationTest < ActiveSupport::TestCase
      test "retry system works end-to-end with exponential backoff" do
        attempts = 0
        config = {
          "retry" => {
            "strategy" => "exponential",
            "max_attempts" => 3,
            "base_delay" => 0.01,
            "jitter" => false,
          },
        }

        coordinator = RetryCoordinator.new

        result = coordinator.execute_with_retry(config) do
          attempts += 1
          raise Net::ReadTimeout, "timeout" if attempts < 3

          "success after #{attempts} attempts"
        end

        assert_equal "success after 3 attempts", result
        assert_equal 3, attempts
      end

      test "retry system fails after max attempts" do
        config = {
          "retry" => {
            "strategy" => "constant",
            "max_attempts" => 2,
            "base_delay" => 0.01,
          },
        }

        coordinator = RetryCoordinator.new
        attempts = 0

        assert_raises(Net::ReadTimeout) do
          coordinator.execute_with_retry(config) do
            attempts += 1
            raise Net::ReadTimeout, "persistent timeout"
          end
        end

        # max_attempts includes retries, so we get initial attempt + 2 retries = 3 total
        assert_equal 3, attempts
      end

      test "shorthand integer configuration works" do
        attempts = 0
        config = { "retry" => 2 }

        coordinator = RetryCoordinator.new

        assert_raises(StandardError) do
          coordinator.execute_with_retry(config) do
            attempts += 1
            raise StandardError, "rate limit exceeded"
          end
        end

        # max_attempts: 2 means initial attempt + 2 retries = 3 total
        assert_equal 3, attempts
      end

      test "no retry when disabled" do
        attempts = 0
        config = { "retry" => false }

        coordinator = RetryCoordinator.new

        assert_raises(StandardError) do
          coordinator.execute_with_retry(config) do
            attempts += 1
            raise StandardError, "error"
          end
        end

        assert_equal 1, attempts
      end

      test "no retry for non-idempotent steps" do
        attempts = 0
        config = {
          "idempotent" => false,
          "retry" => { "max_attempts" => 3 },
        }

        coordinator = RetryCoordinator.new

        assert_raises(StandardError) do
          coordinator.execute_with_retry(config) do
            attempts += 1
            raise StandardError, "error"
          end
        end

        assert_equal 1, attempts
      end

      test "linear backoff strategy integration" do
        events = []
        config = {
          "retry" => {
            "strategy" => "linear",
            "max_attempts" => 3,
            "base_delay" => 0.01,
            "increment" => 0.01,
          },
        }

        # Subscribe to retry events to verify delays
        ActiveSupport::Notifications.subscribe("roast.retry.attempt") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event.payload
        end

        coordinator = RetryCoordinator.new
        attempts = 0

        assert_raises(StandardError) do
          coordinator.execute_with_retry(config) do
            attempts += 1
            raise StandardError, "rate limit"
          end
        end

        # With max_attempts: 3, we get 3 retries after the initial attempt
        assert_equal(4, attempts)
        assert_equal(3, events.size)

        # Verify delays are linear
        assert_in_delta(0.01, events[0][:delay], 0.001)
        assert_in_delta(0.02, events[1][:delay], 0.001)
        assert_in_delta(0.03, events[2][:delay], 0.001)
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.retry.attempt")
      end
    end
  end
end
