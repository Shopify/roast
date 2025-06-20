# frozen_string_literal: true

module Roast
  module Retry
    class StrategyFactory
      STRATEGIES = {
        "exponential" => ExponentialBackoffStrategy,
        "linear" => LinearBackoffStrategy,
        "constant" => ConstantDelayStrategy,
      }.freeze

      def create(config)
        return NullStrategy.new unless config

        # Handle shorthand configuration (just a number)
        if config.is_a?(Integer)
          return ExponentialBackoffStrategy.new("max_attempts" => config)
        end

        strategy_name = config.fetch("strategy", "exponential")
        strategy_class = STRATEGIES.fetch(strategy_name, ExponentialBackoffStrategy)
        strategy_class.new(config)
      end
    end
  end
end
