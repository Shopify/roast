# frozen_string_literal: true

module Roast
  module Retry
    class RetryableError < StandardError
      attr_reader :retry_after

      def initialize(message, retry_after: nil)
        super(message)
        @retry_after = retry_after
      end
    end
  end
end
