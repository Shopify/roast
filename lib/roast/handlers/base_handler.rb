# frozen_string_literal: true

module Roast
  module Handlers
    class BaseHandler
      def before_attempt(attempt)
        # Override in subclasses
      end

      def on_retry(error, attempt)
        # Override in subclasses
      end

      def on_success(attempt)
        # Override in subclasses
      end

      def on_failure(error, attempt)
        # Override in subclasses
      end
    end
  end
end