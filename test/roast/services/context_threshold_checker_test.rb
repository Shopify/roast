# frozen_string_literal: true

require "test_helper"

module Roast
  module Services
    class ContextThresholdCheckerTest < ActiveSupport::TestCase
      def setup
        @checker = ContextThresholdChecker.new
      end

      test "returns false when token count is below threshold" do
        result = @checker.should_compact?(1000, 0.8, 10000)

        assert_equal false, result
      end

      test "returns true when token count exceeds threshold" do
        result = @checker.should_compact?(8500, 0.8, 10000)

        assert_equal true, result
      end

      test "returns true when token count equals threshold" do
        result = @checker.should_compact?(8000, 0.8, 10000)

        assert_equal true, result
      end

      test "handles threshold as percentage" do
        # 50% of 1000 = 500
        assert_equal false, @checker.should_compact?(400, 0.5, 1000)
        assert_equal true, @checker.should_compact?(600, 0.5, 1000)
      end

      test "handles nil max_tokens by using default" do
        # Default is 128k, 80% of that is 102,400
        result = @checker.should_compact?(103000, 0.8, nil)

        assert_equal true, result
      end

      test "returns warning info when approaching threshold" do
        warning = @checker.check_warning_threshold(7500, 0.8, 10000)

        assert_not_nil warning
        assert_equal :approaching_limit, warning[:level]
        assert_equal 75, warning[:percentage_used]
      end

      test "returns nil when well below warning threshold" do
        warning = @checker.check_warning_threshold(5000, 0.8, 10000)

        assert_nil warning
      end

      test "returns critical warning when very close to limit" do
        warning = @checker.check_warning_threshold(9500, 0.8, 10000)

        assert_not_nil warning
        assert_equal :critical, warning[:level]
        assert_equal 95, warning[:percentage_used]
      end
    end
  end
end
