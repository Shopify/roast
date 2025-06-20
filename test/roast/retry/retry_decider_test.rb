# frozen_string_literal: true

require "test_helper"

module Roast
  module Retry
    class RetryDeciderTest < ActiveSupport::TestCase
      def setup
        @decider = RetryDecider.new
      end

      test "returns true for steps without configuration" do
        assert @decider.should_retry_step?(nil)
        assert @decider.should_retry_step?("simple_string")
      end

      test "returns true for hash configuration without retry settings" do
        config = { "model" => "gpt-4", "params" => {} }
        assert @decider.should_retry_step?(config)
      end

      test "returns false when retry is explicitly disabled" do
        config = { "retry" => false }
        refute @decider.should_retry_step?(config)
      end

      test "returns false when step is marked as non-idempotent" do
        config = { "idempotent" => false }
        refute @decider.should_retry_step?(config)
      end

      test "returns true when retry configuration exists" do
        config = { "retry" => { "max_attempts" => 3 } }
        assert @decider.should_retry_step?(config)
      end

      test "returns true when idempotent is true" do
        config = { "idempotent" => true }
        assert @decider.should_retry_step?(config)
      end

      test "idempotent false takes precedence over retry config" do
        config = {
          "retry" => { "max_attempts" => 3 },
          "idempotent" => false,
        }
        refute @decider.should_retry_step?(config)
      end
    end
  end
end
