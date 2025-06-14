# frozen_string_literal: true

module Roast
  module Services
    class ContextThresholdChecker
      # Default max tokens if not specified (128k for GPT-4)
      DEFAULT_MAX_TOKENS = 128_000

      # Warning threshold as percentage of compaction threshold
      WARNING_THRESHOLD_RATIO = 0.9

      # Critical threshold as percentage of max tokens
      CRITICAL_THRESHOLD_RATIO = 0.95

      def should_compact?(token_count, threshold, max_tokens)
        max_tokens ||= DEFAULT_MAX_TOKENS
        token_count >= (max_tokens * threshold)
      end

      def check_warning_threshold(token_count, compaction_threshold, max_tokens)
        max_tokens ||= DEFAULT_MAX_TOKENS
        percentage_used = (token_count.to_f / max_tokens * 100).round

        if token_count >= (max_tokens * CRITICAL_THRESHOLD_RATIO)
          {
            level: :critical,
            percentage_used: percentage_used,
            tokens_used: token_count,
            max_tokens: max_tokens,
          }
        elsif token_count >= (max_tokens * compaction_threshold * WARNING_THRESHOLD_RATIO)
          {
            level: :approaching_limit,
            percentage_used: percentage_used,
            tokens_used: token_count,
            max_tokens: max_tokens,
          }
        end
      end
    end
  end
end
