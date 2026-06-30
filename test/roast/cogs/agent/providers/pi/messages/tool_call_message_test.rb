# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    module Agent::Providers::Pi::Messages
      class ToolCallMessageTest < ActiveSupport::TestCase
        test "format returns nil when name is nil" do
          msg = ToolCallMessage.new(id: "1", name: nil, arguments: {})
          assert_nil msg.format
        end

        test "format renders BASH with the command" do
          msg = ToolCallMessage.new(id: "1", name: "bash", arguments: { command: "ls -la" })
          assert_equal "BASH ls -la", msg.format
        end

        test "format renders a bare BASH when the command is missing" do
          msg = ToolCallMessage.new(id: "1", name: "bash", arguments: {})
          assert_equal "BASH", msg.format
        end

        test "format truncates a long bash command" do
          msg = ToolCallMessage.new(id: "1", name: "bash", arguments: { command: "x" * 100 })
          assert_equal "BASH #{"x" * (ToolCallMessage::TRUNCATE_LIMIT - 3)}...", msg.format
        end

        test "format renders an unhandled tool as NAME key: value, ..." do
          msg = ToolCallMessage.new(
            id: "1",
            name: "web_search",
            arguments: { query: "ruby pluralize", max_results: 5 },
          )
          assert_equal 'WEB_SEARCH max_results: 5, query: "ruby pluralize"', msg.format
        end

        test "format orders arguments by rendered pair length, shortest first" do
          msg = ToolCallMessage.new(
            id: "1",
            name: "search",
            arguments: { longest_key: "a", b: "medium value", c: 1 },
          )
          assert_equal 'SEARCH c: 1, longest_key: "a", b: "medium value"', msg.format
        end

        test "format renders the bare name when an unhandled tool has no arguments" do
          msg = ToolCallMessage.new(id: "1", name: "deploy", arguments: {})
          assert_equal "DEPLOY", msg.format
        end

        test "format truncates a long argument value" do
          msg = ToolCallMessage.new(id: "1", name: "embed", arguments: { text: "x" * 100 })
          assert_equal "EMBED text: #{("x" * 100).inspect[0, ToolCallMessage::TRUNCATE_LIMIT - 3]}...", msg.format
        end

        test "format normalizes non-hash arguments instead of raising" do
          msg = ToolCallMessage.new(id: "1", name: "deploy", arguments: "not a hash")
          assert_equal "DEPLOY", msg.format
        end

        test "format falls back to the generic formatter when a dedicated formatter raises" do
          klass = Class.new(ToolCallMessage) do
            private

            def format_boom
              raise "boom"
            end
          end
          msg = klass.new(id: "1", name: "boom", arguments: { a: 1 })
          assert_equal "BOOM a: 1", msg.format
        end
      end
    end
  end
end
