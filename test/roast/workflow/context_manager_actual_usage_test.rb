# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ContextManagerActualUsageTest < ActiveSupport::TestCase
      def setup
        @manager = ContextManager.new
      end

      test "updates total tokens with actual usage" do
        # First track some estimated tokens
        messages = [{ role: "user", content: "Hello world" }]
        @manager.track_usage(messages)

        initial_tokens = @manager.total_tokens
        assert initial_tokens > 0

        # Update with actual usage
        @manager.update_with_actual_usage(150)

        assert_equal 150, @manager.total_tokens
      end

      test "ignores nil or zero actual usage" do
        @manager.track_usage([{ role: "user", content: "Test" }])
        initial_tokens = @manager.total_tokens

        @manager.update_with_actual_usage(nil)
        assert_equal initial_tokens, @manager.total_tokens

        @manager.update_with_actual_usage(0)
        assert_equal initial_tokens, @manager.total_tokens
      end

      test "tracks when last actual update occurred" do
        assert_nil @manager.instance_variable_get(:@last_actual_update)

        @manager.update_with_actual_usage(100)

        last_update = @manager.instance_variable_get(:@last_actual_update)
        assert_not_nil last_update
        assert_kind_of Time, last_update
        assert_in_delta Time.now.to_f, last_update.to_f, 1.0
      end

      test "resets estimated tokens since update" do
        @manager.instance_variable_set(:@estimated_tokens_since_update, 50)

        @manager.update_with_actual_usage(200)

        assert_equal 0, @manager.instance_variable_get(:@estimated_tokens_since_update)
      end
    end
  end
end
