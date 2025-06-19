# frozen_string_literal: true

module Roast
  module Matchers
    class AlwaysRetryMatcher < BaseMatcher
      def matches?(error)
        true
      end
    end
  end
end
