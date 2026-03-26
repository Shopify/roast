# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolResultMessageTest < ActiveSupport::TestCase
              def setup
                @context = PiInvocation::Context.new
              end

              test "format returns tool name and OK status for successful result" do
                msg = ToolResultMessage.new(
                  tool_call_id: "1",
                  tool_name: "bash",
                  content: "file1.rb\nfile2.rb",
                  is_error: false,
                )

                assert_equal "BASH OK file1.rb\nfile2.rb", msg.format(@context)
              end

              test "format returns tool name and ERROR status for error result" do
                msg = ToolResultMessage.new(
                  tool_call_id: "1",
                  tool_name: "bash",
                  content: "command not found",
                  is_error: true,
                )

                assert_equal "BASH ERROR command not found", msg.format(@context)
              end

              test "format truncates long content" do
                long_content = "x" * 300
                msg = ToolResultMessage.new(
                  tool_call_id: "1",
                  tool_name: "read",
                  content: long_content,
                  is_error: false,
                )

                result = msg.format(@context)
                assert result.length < 220
                assert result.end_with?("...")
              end

              test "format handles nil content" do
                msg = ToolResultMessage.new(
                  tool_call_id: "1",
                  tool_name: "bash",
                  content: nil,
                  is_error: false,
                )

                assert_equal "BASH OK", msg.format(@context)
              end

              test "format uses tool name from context when tool_name is nil" do
                tool_call = Messages::ToolCallMessage.new(id: "1", name: "edit", arguments: {})
                @context.add_tool_call(tool_call)

                msg = ToolResultMessage.new(
                  tool_call_id: "1",
                  tool_name: nil,
                  content: "done",
                  is_error: false,
                )

                result = msg.format(@context)
                assert result.start_with?("EDIT")
              end

              test "format falls back to unknown when no tool name available" do
                msg = ToolResultMessage.new(
                  tool_call_id: "nonexistent",
                  tool_name: nil,
                  content: "result",
                  is_error: false,
                )

                result = msg.format(@context)
                assert result.start_with?("UNKNOWN")
              end
            end
          end
        end
      end
    end
  end
end
