# frozen_string_literal: true

module Roast
  module Matchers
    class BaseMatcher
      def matches?(error)
        raise NotImplementedError, "Subclasses must implement #matches?"
      end
    end
  end
end
