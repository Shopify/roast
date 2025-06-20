# frozen_string_literal: true

module Roast
  module Retry
    class RetryDecider
      def should_retry_step?(step_config)
        # Steps are retryable by default unless explicitly disabled
        return true unless step_config.is_a?(Hash)

        # Check if step has retry configuration
        return false if step_config["retry"] == false

        # Check if step is marked as non-idempotent
        return false if step_config["idempotent"] == false

        true
      end
    end
  end
end
