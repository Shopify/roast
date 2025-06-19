# frozen_string_literal: true

module Roast
  class RetryPolicyFactory
    class << self
      def build(config)
        return default_policy unless config

        strategy = build_strategy(config[:strategy] || "exponential")
        matcher = build_matcher(config[:matcher])
        handlers = build_handlers(config[:handlers])

        RetryPolicy.new(
          strategy: strategy,
          max_attempts: config[:max_attempts] || 3,
          matcher: matcher,
          handlers: handlers,
          base_delay: config[:base_delay] || 1,
          max_delay: config[:max_delay] || 60,
          jitter: config[:jitter] || false,
        )
      end

      def default_policy
        RetryPolicy.new(
          strategy: RetryStrategies::ExponentialBackoffStrategy.new,
          max_attempts: 3,
          base_delay: 1,
          max_delay: 60,
          jitter: true,
          handlers: [
            Handlers::LoggingHandler.new,
            Handlers::InstrumentationHandler.new,
          ],
        )
      end

      private

      def build_strategy(strategy_name)
        case strategy_name.to_s
        when "exponential"
          RetryStrategies::ExponentialBackoffStrategy.new
        when "linear"
          RetryStrategies::LinearBackoffStrategy.new
        when "fixed"
          RetryStrategies::FixedDelayStrategy.new
        else
          raise ArgumentError, "Unknown retry strategy: #{strategy_name}"
        end
      end

      def build_matcher(matcher_config)
        return unless matcher_config

        case matcher_config[:type]
        when "error_type"
          error_types = matcher_config[:errors].map { |e| Object.const_get(e) }
          Matchers::ErrorTypeMatcher.new(error_types)
        when "error_message"
          Matchers::ErrorMessageMatcher.new(matcher_config[:pattern])
        when "http_status"
          Matchers::HttpStatusMatcher.new(matcher_config[:statuses])
        when "rate_limit"
          Matchers::RateLimitMatcher.new
        when "composite"
          matchers = matcher_config[:matchers].map { |m| build_matcher(m) }
          Matchers::CompositeMatcher.new(matchers, operator: matcher_config[:operator]&.to_sym || :any)
        else
          raise ArgumentError, "Unknown matcher type: #{matcher_config[:type]}"
        end
      end

      def build_handlers(handler_configs)
        return [] unless handler_configs

        handler_configs.map do |handler_config|
          case handler_config[:type]
          when "logging"
            Handlers::LoggingHandler.new
          when "instrumentation"
            Handlers::InstrumentationHandler.new(namespace: handler_config[:namespace])
          when "exponential_backoff"
            Handlers::ExponentialBackoffHandler.new(
              base_delay: handler_config[:base_delay],
              max_delay: handler_config[:max_delay],
            )
          else
            raise ArgumentError, "Unknown handler type: #{handler_config[:type]}"
          end
        end
      end
    end
  end
end
