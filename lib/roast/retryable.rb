# frozen_string_literal: true

module Roast
  class Retryable
    attr_reader :policy, :metrics

    def initialize(policy:, metrics: nil)
      @policy = policy
      @metrics = metrics || Metrics::NullMetrics.new
    end

    def execute(&block)
      attempt = 0
      begin_time = Time.now

      begin
        attempt += 1
        notify_before_attempt(attempt)
        
        result = block.call
        notify_success(attempt, Time.now - begin_time)
        result
      rescue => error
        if policy.should_retry?(error, attempt)
          notify_retry(error, attempt)
          delay = policy.delay_for(attempt)
          sleep(delay)
          retry
        else
          notify_failure(error, attempt, Time.now - begin_time)
          raise
        end
      end
    end

    private

    def notify_before_attempt(attempt)
      policy.handlers.each { |handler| handler.before_attempt(attempt) }
      metrics.record_attempt(attempt)
    end

    def notify_retry(error, attempt)
      policy.handlers.each { |handler| handler.on_retry(error, attempt) }
      metrics.record_retry(attempt)
    end

    def notify_success(attempt, duration)
      policy.handlers.each { |handler| handler.on_success(attempt) }
      metrics.record_success(attempt, duration)
    end

    def notify_failure(error, attempt, duration)
      policy.handlers.each { |handler| handler.on_failure(error, attempt) }
      metrics.record_failure(attempt, duration)
    end
  end
end