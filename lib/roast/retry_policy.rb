# frozen_string_literal: true

module Roast
  class RetryPolicy
    attr_reader :strategy, :max_attempts, :matcher, :handlers, :base_delay, :max_delay, :jitter

    def initialize(
      strategy:,
      max_attempts: 3,
      matcher: nil,
      handlers: [],
      base_delay: 1,
      max_delay: 60,
      jitter: false
    )
      @strategy = strategy
      @max_attempts = max_attempts
      @matcher = matcher || Matchers::AlwaysRetryMatcher.new
      @handlers = Array(handlers)
      @base_delay = base_delay
      @max_delay = max_delay
      @jitter = jitter
    end

    def should_retry?(error, attempt)
      attempt < max_attempts && matcher.matches?(error)
    end

    def delay_for(attempt)
      delay = strategy.calculate(attempt, base_delay: base_delay, max_delay: max_delay)
      jitter ? add_jitter(delay) : delay
    end

    private

    def add_jitter(delay)
      jitter_amount = delay * 0.1
      delay + (rand * 2 - 1) * jitter_amount
    end
  end
end