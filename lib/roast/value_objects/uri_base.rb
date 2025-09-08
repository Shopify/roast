# typed: true
# frozen_string_literal: true

module Roast
  module ValueObjects
    # Value object representing a URI base with validation
    class UriBase
      class InvalidUriBaseError < Roast::Error; end

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
        return false unless other.is_a?(UriBase)

        value == other.value
      end
      alias_method :eql?, :==

      def hash
        [self.class, @value].hash
      end

      private

      def validate!
        return if @value.nil? # Allow nil URI base, just not empty strings

        raise InvalidUriBaseError, "URI base cannot be an empty string" if @value.strip.empty?
      end
    end
  end
end
