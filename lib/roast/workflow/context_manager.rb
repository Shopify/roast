# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    class ContextManager
      attr_reader :total_tokens

      def initialize(token_counter: nil, threshold_checker: nil)
        @token_counter = token_counter || Services::TokenCountingService.new
        @threshold_checker = threshold_checker || Services::ContextThresholdChecker.new
        @total_tokens = 0
        @agent_tokens = 0
        @message_count = 0
        @agent_call_count = 0
        @config = default_config
        @last_actual_update = nil
        @estimated_tokens_since_update = 0
      end

      def configure(config)
        @config = default_config.merge(config)
      end

      def track_usage(messages)
        current_tokens = @token_counter.count_messages(messages)
        @total_tokens += current_tokens
        @message_count += messages.size

        {
          current_tokens: current_tokens,
          total_tokens: @total_tokens,
        }
      end

      def track_agent_usage(prompt, response = nil)
        agent_tokens = @token_counter.count_agent_call(prompt, response)
        @agent_tokens += agent_tokens
        @total_tokens += agent_tokens
        @agent_call_count += 1

        {
          current_agent_tokens: agent_tokens,
          total_agent_tokens: @agent_tokens,
          total_tokens: @total_tokens,
        }
      end

      def should_compact?(token_count = @total_tokens)
        return false unless @config[:enabled]

        @threshold_checker.should_compact?(
          token_count,
          @config[:threshold],
          @config[:max_tokens],
        )
      end

      def check_warnings(token_count = @total_tokens)
        return unless @config[:enabled]

        warning = @threshold_checker.check_warning_threshold(
          token_count,
          @config[:threshold],
          @config[:max_tokens],
        )

        if warning
          ActiveSupport::Notifications.instrument("roast.context_warning", warning)
        end
      end

      def reset
        @total_tokens = 0
        @agent_tokens = 0
        @message_count = 0
        @agent_call_count = 0
      end

      def statistics
        general_tokens = @total_tokens - @agent_tokens
        {
          total_tokens: @total_tokens,
          general_tokens: general_tokens,
          agent_tokens: @agent_tokens,
          message_count: @message_count,
          agent_call_count: @agent_call_count,
          average_tokens_per_message: @message_count > 0 ? general_tokens / @message_count : 0,
          average_tokens_per_agent_call: @agent_call_count > 0 ? @agent_tokens / @agent_call_count : 0,
        }
      end

      def update_with_actual_usage(actual_total)
        return unless actual_total && actual_total > 0

        @total_tokens = actual_total
        @last_actual_update = Time.now
        @estimated_tokens_since_update = 0
      end

      private

      def default_config
        {
          enabled: true,
          threshold: 0.8,
          max_tokens: nil, # Will use default from threshold checker
        }
      end
    end
  end
end
