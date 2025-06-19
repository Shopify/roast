# frozen_string_literal: true

require "test_helper"

module Roast
  module Matchers
    class CompositeMatcherTest < ActiveSupport::TestCase
      test "matches with any operator when at least one matcher matches" do
        matcher1 = ErrorTypeMatcher.new(ArgumentError)
        matcher2 = ErrorTypeMatcher.new(RuntimeError)
        composite = CompositeMatcher.new([matcher1, matcher2], operator: :any)
        
        assert composite.matches?(ArgumentError.new)
        assert composite.matches?(RuntimeError.new)
        refute composite.matches?(StandardError.new)
      end

      test "matches with all operator when all matchers match" do
        matcher1 = ErrorTypeMatcher.new(StandardError)
        matcher2 = ErrorMessageMatcher.new("timeout")
        composite = CompositeMatcher.new([matcher1, matcher2], operator: :all)
        
        assert composite.matches?(StandardError.new("Connection timeout"))
        refute composite.matches?(StandardError.new("Connection refused"))
        assert composite.matches?(ArgumentError.new("timeout"))  # ArgumentError is a StandardError
      end

      test "defaults to any operator" do
        matcher1 = ErrorTypeMatcher.new(ArgumentError)
        matcher2 = ErrorTypeMatcher.new(RuntimeError)
        composite = CompositeMatcher.new([matcher1, matcher2])
        
        assert composite.matches?(ArgumentError.new)
        assert composite.matches?(RuntimeError.new)
      end

      test "raises error for unknown operator" do
        matcher = ErrorTypeMatcher.new(StandardError)
        composite = CompositeMatcher.new([matcher], operator: :invalid)
        
        assert_raises(ArgumentError) do
          composite.matches?(StandardError.new)
        end
      end
    end
  end
end