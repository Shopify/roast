# frozen_string_literal: true

module Roast
  module Workflow
    # Enhanced error handler with retry policy support
    class RetryableErrorHandler < ErrorHandler
      def with_error_handling(step_name, resource_type: nil, retry_policy: nil, &block)
        if retry_policy
          execute_with_retry(step_name, resource_type, retry_policy)
        else
          super(step_name, resource_type: resource_type, &block)
        end
      end

      private

      def execute_with_retry(step_name, resource_type, retry_policy, &block)
        metrics = Metrics::RetryMetrics.new
        retryable = Retryable.new(policy: retry_policy, metrics: metrics)

        retryable.execute do
          super(step_name, resource_type: resource_type, &block)
        end
      ensure
        log_retry_metrics(step_name, metrics) if metrics.attempts > 1
      end

      def log_retry_metrics(step_name, metrics)
        ActiveSupport::Notifications.instrument("roast.step.retry_metrics", {
          step_name: step_name,
          metrics: metrics.to_h,
        })

        if metrics.successes > 0
          Roast::Helpers::Logger.info(
            "Step '#{step_name}' succeeded after #{metrics.attempts} attempts",
          )
        end
      end
    end
  end
end
