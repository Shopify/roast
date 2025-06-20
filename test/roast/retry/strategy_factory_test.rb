# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class StrategyFactoryTest < ActiveSupport::TestCase
      def setup
        @factory = StrategyFactory.new
      end

      test "creates NullStrategy when no config provided" do
        strategy = @factory.create(nil)
        assert_instance_of NullStrategy, strategy
      end

      test "creates ExponentialBackoffStrategy for integer config" do
        strategy = @factory.create(5)
        assert_instance_of ExponentialBackoffStrategy, strategy
        assert_equal 5, strategy.max_attempts
      end

      test "creates ExponentialBackoffStrategy by name" do
        config = { "strategy" => "exponential", "max_attempts" => 3 }
        strategy = @factory.create(config)
        assert_instance_of ExponentialBackoffStrategy, strategy
        assert_equal 3, strategy.max_attempts
      end

      test "creates LinearBackoffStrategy by name" do
        config = { "strategy" => "linear", "base_delay" => 2.0 }
        strategy = @factory.create(config)
        assert_instance_of LinearBackoffStrategy, strategy
        assert_equal 2.0, strategy.base_delay
      end

      test "creates ConstantDelayStrategy by name" do
        config = { "strategy" => "constant", "base_delay" => 1.5 }
        strategy = @factory.create(config)
        assert_instance_of ConstantDelayStrategy, strategy
        assert_equal 1.5, strategy.base_delay
      end

      test "defaults to ExponentialBackoffStrategy for unknown strategy" do
        config = { "strategy" => "unknown", "max_attempts" => 4 }
        strategy = @factory.create(config)
        assert_instance_of ExponentialBackoffStrategy, strategy
        assert_equal 4, strategy.max_attempts
      end

      test "defaults to ExponentialBackoffStrategy when strategy not specified" do
        config = { "max_attempts" => 2 }
        strategy = @factory.create(config)
        assert_instance_of ExponentialBackoffStrategy, strategy
        assert_equal 2, strategy.max_attempts
      end
    end
  end
end
