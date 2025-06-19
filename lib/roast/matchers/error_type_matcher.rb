# frozen_string_literal: true

module Roast
  module Matchers
    class ErrorTypeMatcher < BaseMatcher
      attr_reader :error_types

      def initialize(error_types)
        @error_types = Array(error_types)
      end

      def matches?(error)
        error_types.any? { |type| error.is_a?(type) }
      end
    end
  end
end