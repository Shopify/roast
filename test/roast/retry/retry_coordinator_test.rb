# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class RetryCoordinatorTest < ActiveSupport::TestCase
      def setup
        @executor = mock_executor
        @decider = mock_decider(true)
        @factory = mock_factory
        @coordinator = RetryCoordinator.new(
          executor: @executor,
          decider: @decider,
          strategy_factory: @factory,
        )
      end

      test "executes without retry when decider returns false" do
        decider = mock_decider(false)
        coordinator = RetryCoordinator.new(
          executor: @executor,
          decider: decider,
          strategy_factory: @factory,
        )

        result = coordinator.execute_with_retry({}) { "success" }

        assert_equal "success", result
      end

      test "uses retry executor when step should be retried" do
        strategy = Object.new
        factory = mock_factory(strategy)
        executor = mock_executor

        # Set expectation that executor.execute will be called
        executed = false
        received_strategy = nil
        executor.define_singleton_method(:execute) do |strat, &block|
          executed = true
          received_strategy = strat
          block.call
        end

        coordinator = RetryCoordinator.new(
          executor: executor,
          decider: @decider,
          strategy_factory: factory,
        )

        config = { "retry" => { "max_attempts" => 3 } }
        result = coordinator.execute_with_retry(config) { "success" }

        assert executed, "Executor should have been called"
        assert_equal strategy, received_strategy
        assert_equal "success", result
      end

      test "passes retry config to strategy factory" do
        retry_config = { "strategy" => "linear", "max_attempts" => 5 }
        config = { "retry" => retry_config }

        factory_called = false
        received_config = nil
        factory = Object.new
        factory.define_singleton_method(:create) do |cfg|
          factory_called = true
          received_config = cfg
          NullStrategy.new
        end

        coordinator = RetryCoordinator.new(
          executor: @executor,
          decider: @decider,
          strategy_factory: factory,
        )

        coordinator.execute_with_retry(config) { "success" }

        assert factory_called, "Factory should have been called with retry config"
        assert_equal retry_config, received_config
      end

      test "handles nil step config" do
        result = @coordinator.execute_with_retry(nil) { "success" }
        assert_equal "success", result
      end

      test "handles string step config" do
        result = @coordinator.execute_with_retry("step_name") { "success" }
        assert_equal "success", result
      end

      test "creates strategy from factory when retry config is nil" do
        factory_called = false
        received_config = :not_set
        factory = Object.new
        factory.define_singleton_method(:create) do |cfg|
          factory_called = true
          received_config = cfg
          NullStrategy.new
        end

        coordinator = RetryCoordinator.new(
          executor: @executor,
          decider: @decider,
          strategy_factory: factory,
        )

        coordinator.execute_with_retry({}) { "success" }

        assert factory_called, "Factory should have been called with nil config"
        assert_nil received_config
      end

      private

      def mock_executor
        executor = Object.new
        executor.define_singleton_method(:execute) do |_strategy, &block|
          block.call
        end
        executor
      end

      def mock_decider(should_retry)
        decider = Object.new
        decider.define_singleton_method(:should_retry_step?) do |_config|
          should_retry
        end
        decider
      end

      def mock_factory(strategy = nil)
        factory = Object.new
        factory.define_singleton_method(:create) do |_config|
          strategy || NullStrategy.new
        end
        factory
      end
    end
  end
end
