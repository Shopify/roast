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

        test "format renders READ with the path" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb" })
          assert_equal "READ lib/roast.rb", msg.format
        end

        test "format renders a bare READ when the path is missing" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: {})
          assert_equal "READ", msg.format
        end

        test "format renders READ with a closed line range when offset and limit are set" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb", offset: 30, limit: 51 })
          assert_equal "READ lib/roast.rb (lines 30–80)", msg.format
        end

        test "format defaults the read offset to 1 when only limit is given" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb", limit: 50 })
          assert_equal "READ lib/roast.rb (lines 1–50)", msg.format
        end

        test "format renders an open-ended read range from offset when limit is absent" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb", offset: 30 })
          assert_equal "READ lib/roast.rb (from line 30)", msg.format
        end

        test "format falls back to the open-ended range when read limit is non-positive" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb", offset: 30, limit: 0 })
          assert_equal "READ lib/roast.rb (from line 30)", msg.format
        end

        test "format omits the range entirely when read limit is non-positive and no offset is given" do
          msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "lib/roast.rb", limit: 0 })
          assert_equal "READ lib/roast.rb", msg.format
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
