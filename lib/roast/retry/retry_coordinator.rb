# frozen_string_literal: true

module Roast
  module Retry
    class RetryCoordinator
      def initialize(
        executor: RetryExecutor.new,
        decider: RetryDecider.new,
        strategy_factory: StrategyFactory.new
      )
        @executor = executor
        @decider = decider
        @strategy_factory = strategy_factory
      end

      def execute_with_retry(step_config, &block)
        unless @decider.should_retry_step?(step_config)
          return yield
        end

        retry_config = step_config.is_a?(Hash) ? step_config["retry"] : nil
        strategy = @strategy_factory.create(retry_config)

        @executor.execute(strategy, &block)
      end
    end
  end
end
