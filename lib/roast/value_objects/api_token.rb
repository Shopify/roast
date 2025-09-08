# typed: true
# frozen_string_literal: true

module Roast
  module ValueObjects
    # Value object representing an API token with validation
    class ApiToken
      class InvalidTokenError < Roast::Error; end

      attr_reader :value

      def initialize(value)
        @value = value&.to_s
        validate!
        freeze
      end

      def present?
        !blank?
      end

      def blank?
        @value.nil? || @value.strip.empty?
      end

      def to_s
        @value
      end

      def ==(other)
        return false unless other.is_a?(ApiToken)

        value == other.value
      end
      alias_method :eql?, :==

      def hash
        [self.class, @value].hash
      end

      private

      def validate!
        return if @value.nil? # Allow nil tokens, just not empty strings

        raise InvalidTokenError, "API token cannot be an empty string" if @value.strip.empty?
      end
    end
  end
end
