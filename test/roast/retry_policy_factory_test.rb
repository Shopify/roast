# frozen_string_literal: true

require "test_helper"

module Roast
  class RetryPolicyFactoryTest < ActiveSupport::TestCase
    test "builds default policy when config is nil" do
      policy = RetryPolicyFactory.build(nil)
      
      assert_kind_of RetryPolicy, policy
      assert_kind_of RetryStrategies::ExponentialBackoffStrategy, policy.strategy
      assert_equal 3, policy.max_attempts
      assert_equal 1, policy.base_delay
      assert_equal 60, policy.max_delay
      assert_equal true, policy.jitter
      assert_equal 2, policy.handlers.size
    end

    test "builds policy with exponential strategy" do
      config = { strategy: "exponential", max_attempts: 5 }
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of RetryStrategies::ExponentialBackoffStrategy, policy.strategy
      assert_equal 5, policy.max_attempts
    end

    test "builds policy with linear strategy" do
      config = { strategy: "linear", base_delay: 2 }
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of RetryStrategies::LinearBackoffStrategy, policy.strategy
      assert_equal 2, policy.base_delay
    end

    test "builds policy with fixed strategy" do
      config = { strategy: "fixed", max_delay: 120 }
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of RetryStrategies::FixedDelayStrategy, policy.strategy
      assert_equal 120, policy.max_delay
    end

    test "raises error for unknown strategy" do
      config = { strategy: "unknown" }
      
      assert_raises(ArgumentError) do
        RetryPolicyFactory.build(config)
      end
    end

    test "builds error type matcher" do
      config = {
        strategy: "exponential",
        matcher: {
          type: "error_type",
          errors: ["StandardError", "RuntimeError"]
        }
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of Matchers::ErrorTypeMatcher, policy.matcher
      assert policy.matcher.matches?(StandardError.new)
      assert policy.matcher.matches?(RuntimeError.new)
    end

    test "builds error message matcher" do
      config = {
        strategy: "exponential",
        matcher: {
          type: "error_message",
          pattern: "timeout"
        }
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of Matchers::ErrorMessageMatcher, policy.matcher
      assert policy.matcher.matches?(StandardError.new("Connection timeout"))
    end

    test "builds http status matcher" do
      config = {
        strategy: "exponential",
        matcher: {
          type: "http_status",
          statuses: [429, 503]
        }
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of Matchers::HttpStatusMatcher, policy.matcher
    end

    test "builds rate limit matcher" do
      config = {
        strategy: "exponential",
        matcher: {
          type: "rate_limit"
        }
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of Matchers::RateLimitMatcher, policy.matcher
    end

    test "builds composite matcher" do
      config = {
        strategy: "exponential",
        matcher: {
          type: "composite",
          operator: "all",
          matchers: [
            { type: "error_type", errors: ["StandardError"] },
            { type: "error_message", pattern: "timeout" }
          ]
        }
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_kind_of Matchers::CompositeMatcher, policy.matcher
    end

    test "builds handlers" do
      config = {
        strategy: "exponential",
        handlers: [
          { type: "logging" },
          { type: "instrumentation", namespace: "custom.retry" }
        ]
      }
      
      policy = RetryPolicyFactory.build(config)
      
      assert_equal 2, policy.handlers.size
      assert_kind_of Handlers::LoggingHandler, policy.handlers[0]
      assert_kind_of Handlers::InstrumentationHandler, policy.handlers[1]
    end

    test "raises error for unknown handler type" do
      config = {
        strategy: "exponential",
        handlers: [{ type: "unknown" }]
      }
      
      assert_raises(ArgumentError) do
        RetryPolicyFactory.build(config)
      end
    end
  end
end