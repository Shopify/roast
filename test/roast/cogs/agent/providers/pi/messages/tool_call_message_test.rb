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

        test "format renders an unhandled tool as NAME key: value, ..." do
          msg = ToolCallMessage.new(
            id: "1",
            name: "web_search",
            arguments: { query: "ruby pluralize", max_results: 5 },
          )
          assert_equal 'WEB_SEARCH query: "ruby pluralize", max_results: 5', msg.format
        end

        test "format renders the bare name when an unhandled tool has no arguments" do
          msg = ToolCallMessage.new(id: "1", name: "deploy", arguments: {})
          assert_equal "DEPLOY", msg.format
        end

        test "format truncates a long argument value" do
          msg = ToolCallMessage.new(id: "1", name: "embed", arguments: { text: "x" * 100 })
          assert_equal "EMBED text: #{("x" * 100).inspect[0, ToolCallMessage::TRUNCATE_LIMIT - 3]}...", msg.format
        end
      end
    end
  end
end
