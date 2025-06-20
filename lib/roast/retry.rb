# frozen_string_literal: true

module Roast
  module Retry
    autoload :RetryCoordinator, "roast/retry/retry_coordinator"
    autoload :RetryExecutor, "roast/retry/retry_executor"
    autoload :RetryStrategy, "roast/retry/retry_strategy"
    autoload :StrategyFactory, "roast/retry/strategy_factory"
    autoload :ExponentialBackoffStrategy, "roast/retry/exponential_backoff_strategy"
    autoload :LinearBackoffStrategy, "roast/retry/linear_backoff_strategy"
    autoload :ConstantDelayStrategy, "roast/retry/constant_delay_strategy"
    autoload :NullStrategy, "roast/retry/null_strategy"
    autoload :RetryableError, "roast/retry/retryable_error"
    autoload :RetryDecider, "roast/retry/retry_decider"
  end
end
