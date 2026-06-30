# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    module Agent::Providers::Pi::Messages
      class ToolResultMessageTest < ActiveSupport::TestCase
        def setup
          @context = Roast::Cogs::Agent::Providers::Pi::PiInvocation::Context.new
        end

        test "format summarizes bash output with a line count and preview" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "bash",
            content: "file1.rb\nfile2.rb",
            is_error: false,
          )

          assert_equal "BASH OK 2 lines · file1.rb", msg.format(@context)
        end

        test "format pluralizes a single line of bash output" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "bash",
            content: "hello world",
            is_error: false,
          )

          assert_equal "BASH OK 1 line · hello world", msg.format(@context)
        end

        test "format reports zero lines when bash produced no output" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "bash",
            content: nil,
            is_error: false,
          )

          assert_equal "BASH OK 0 lines", msg.format(@context)
        end

        test "format renders NAME ERROR with the message for an error result" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "bash",
            content: "command not found",
            is_error: true,
          )

          assert_equal "BASH ERROR command not found", msg.format(@context)
        end

        test "format does not truncate an error message" do
          long_message = "boom " * 60
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "read",
            content: long_message,
            is_error: true,
          )

          assert_equal "READ ERROR #{long_message.strip}", msg.format(@context)
        end

        test "format renders a bare NAME ERROR when there is no content" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "bash",
            content: nil,
            is_error: true,
          )

          assert_equal "BASH ERROR", msg.format(@context)
        end

        test "format renders NAME OK with a one-line preview for an unhandled tool" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "web_search",
            content: "3 results\nmore detail",
            is_error: false,
          )

          assert_equal "WEB_SEARCH OK 3 results", msg.format(@context)
        end

        test "format renders a bare NAME OK when there is no content" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "deploy",
            content: nil,
            is_error: false,
          )

          assert_equal "DEPLOY OK", msg.format(@context)
        end

        test "format truncates a long preview" do
          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: "web_search",
            content: "x" * 300,
            is_error: false,
          )

          assert_equal "WEB_SEARCH OK #{"x" * (ToolResultMessage::TRUNCATE_LIMIT - 3)}...", msg.format(@context)
        end

        test "format resolves the tool name from the originating call when the result omits it" do
          @context.add_tool_call(ToolCallMessage.new(id: "1", name: "deploy", arguments: {}))

          msg = ToolResultMessage.new(
            tool_call_id: "1",
            tool_name: nil,
            content: "done",
            is_error: false,
          )

          assert_equal "DEPLOY OK done", msg.format(@context)
        end

        test "format falls back to UNKNOWN when no tool name is available" do
          msg = ToolResultMessage.new(
            tool_call_id: "nonexistent",
            tool_name: nil,
            content: "result",
            is_error: false,
          )

          assert_equal "UNKNOWN OK result", msg.format(@context)
        end
      end
    end
  end
end
