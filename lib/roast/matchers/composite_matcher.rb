# frozen_string_literal: true

module Roast
  module Matchers
    class CompositeMatcher < BaseMatcher
      attr_reader :matchers, :operator

      def initialize(matchers, operator: :any)
        super()
        @matchers = Array(matchers)
        @operator = operator
      end

      def matches?(error)
        case operator
        when :any
          matchers.any? { |matcher| matcher.matches?(error) }
        when :all
          matchers.all? { |matcher| matcher.matches?(error) }
        else
          raise ArgumentError, "Unknown operator: #{operator}"
        end
      end
    end
  end
end
