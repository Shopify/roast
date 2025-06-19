# frozen_string_literal: true

module Roast
  module Handlers
    class InstrumentationHandler < BaseHandler
      attr_reader :namespace

      def initialize(namespace: "roast.retry")
        @namespace = namespace
      end

      def before_attempt(attempt)
        ActiveSupport::Notifications.instrument("#{namespace}.attempt", attempt: attempt)
      end

      def on_retry(error, attempt)
        ActiveSupport::Notifications.instrument("#{namespace}.retry", {
          attempt: attempt,
          error_class: error.class.name,
          error_message: error.message
        })
      end

      def on_success(attempt)
        ActiveSupport::Notifications.instrument("#{namespace}.success", attempt: attempt)
      end

      def on_failure(error, attempt)
        ActiveSupport::Notifications.instrument("#{namespace}.failure", {
          attempt: attempt,
          error_class: error.class.name,
          error_message: error.message
        })
      end
    end
  end
end