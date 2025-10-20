# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ContextManagerTest < ActiveSupport::TestCase
      def setup
        @token_counter = mock("token_counter")
        @threshold_checker = mock("threshold_checker")
        @manager = ContextManager.new(
          token_counter: @token_counter,
          threshold_checker: @threshold_checker,
        )
      end

      test "tracks token usage for messages" do
        messages = [{ role: "user", content: "Hello" }]
        @token_counter.expects(:count_messages).with(messages).returns(100)

        result = @manager.track_usage(messages)

        assert_equal 100, result[:current_tokens]
        assert_equal 100, @manager.total_tokens
      end

      test "accumulates token usage across multiple calls" do
        messages1 = [{ role: "user", content: "Hello" }]
        messages2 = [{ role: "assistant", content: "Hi there" }]

        @token_counter.expects(:count_messages).with(messages1).returns(100)
        @token_counter.expects(:count_messages).with(messages2).returns(150)

        @manager.track_usage(messages1)
        @manager.track_usage(messages2)

        assert_equal 250, @manager.total_tokens
      end

      test "checks if compaction needed based on configuration" do
        config = {
          enabled: true,
          threshold: 0.8,
          max_tokens: 1000,
        }
        @manager.configure(config)

        @threshold_checker.expects(:should_compact?).with(800, 0.8, 1000).returns(true)

        assert @manager.should_compact?(800)
      end

      test "returns false for compaction when disabled" do
        config = { enabled: false }
        @manager.configure(config)

        @threshold_checker.expects(:should_compact?).never

        assert_equal false, @manager.should_compact?(999999)
      end

      test "emits warning notifications when approaching limit" do
        config = {
          enabled: true,
          threshold: 0.8,
          max_tokens: 1000,
        }
        @manager.configure(config)

        warning = { level: :approaching_limit, percentage_used: 75 }
        @threshold_checker.expects(:check_warning_threshold).with(750, 0.8, 1000).returns(warning)

        notifications = []
        ActiveSupport::Notifications.subscribe("roast.context_warning") do |*args|
          notifications << ActiveSupport::Notifications::Event.new(*args)
        end

        @manager.check_warnings(750)

        assert_equal(1, notifications.size)
        assert_equal(:approaching_limit, notifications.first.payload[:level])
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.context_warning")
      end

      test "does not emit warnings when well below threshold" do
        config = {
          enabled: true,
          threshold: 0.8,
          max_tokens: 1000,
        }
        @manager.configure(config)

        @threshold_checker.expects(:check_warning_threshold).with(100, 0.8, 1000).returns(nil)

        notifications = []
        ActiveSupport::Notifications.subscribe("roast.context_warning") do |*args|
          notifications << args
        end

        @manager.check_warnings(100)

        assert_equal(0, notifications.size)
      ensure
        ActiveSupport::Notifications.unsubscribe("roast.context_warning")
      end

      test "resets token count" do
        @token_counter.expects(:count_messages).returns(100)

        @manager.track_usage([{ role: "user", content: "Hello" }])
        assert_equal 100, @manager.total_tokens

        @manager.reset
        assert_equal 0, @manager.total_tokens
      end

      test "provides context statistics" do
        @token_counter.expects(:count_messages).returns(500).twice

        @manager.track_usage([{ role: "user", content: "First" }])
        @manager.track_usage([{ role: "assistant", content: "Second" }])

        stats = @manager.statistics

        assert_equal 1000, stats[:total_tokens]
        assert_equal 1000, stats[:general_tokens]
        assert_equal 0, stats[:agent_tokens]
        assert_equal 2, stats[:message_count]
        assert_equal 0, stats[:agent_call_count]
        assert_equal 500, stats[:average_tokens_per_message]
        assert_equal 0, stats[:average_tokens_per_agent_call]
      end

      test "tracks agent usage with prompt and response" do
        prompt = "Test prompt"
        response = "Test response"
        @token_counter.expects(:count_agent_call).with(prompt, response).returns(300)

        result = @manager.track_agent_usage(prompt, response)

        assert_equal 300, result[:current_agent_tokens]
        assert_equal 300, result[:total_agent_tokens]
        assert_equal 300, result[:total_tokens]
      end

      test "tracks both general and agent usage together" do
        messages = [{ role: "user", content: "Hello" }]
        @token_counter.expects(:count_messages).with(messages).returns(100)
        @token_counter.expects(:count_agent_call).with("prompt", "response").returns(200)

        @manager.track_usage(messages)
        @manager.track_agent_usage("prompt", "response")

        stats = @manager.statistics
        assert_equal 300, stats[:total_tokens]
        assert_equal 100, stats[:general_tokens]
        assert_equal 200, stats[:agent_tokens]
        assert_equal 1, stats[:message_count]
        assert_equal 1, stats[:agent_call_count]
      end
    end
  end
end
