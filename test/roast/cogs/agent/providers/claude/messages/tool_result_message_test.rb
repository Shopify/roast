# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ToolResultMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { tool_use_id: "tool_123", content: "Result content", is_error: false }
                @message = ToolResultMessage.new(type: :tool_result, hash: @hash.dup)
              end

              test "initialize sets tool_use_id from hash" do
                assert_equal "tool_123", @message.tool_use_id
              end

              test "initialize sets content from hash" do
                assert_equal "Result content", @message.content
              end

              test "initialize sets is_error from hash" do
                refute @message.is_error
              end

              test "initialize removes tool_use_id from hash" do
                hash = { tool_use_id: "123" }
                ToolResultMessage.new(type: :tool_result, hash:)

                refute hash.key?(:tool_use_id)
              end

              test "initialize removes content from hash" do
                hash = { content: "test" }
                ToolResultMessage.new(type: :tool_result, hash:)

                refute hash.key?(:content)
              end

              test "initialize removes is_error from hash" do
                hash = { is_error: true }
                ToolResultMessage.new(type: :tool_result, hash:)

                refute hash.key?(:is_error)
              end

              test "initialize removes role from hash" do
                hash = { role: :user }
                ToolResultMessage.new(type: :tool_result, hash:)

                refute hash.key?(:role)
              end

              test "initialize defaults is_error to false" do
                hash = { tool_use_id: "123" }
                message = ToolResultMessage.new(type: :tool_result, hash:)

                refute message.is_error
              end

              test "initialize allows is_error true" do
                hash = { is_error: true }
                message = ToolResultMessage.new(type: :tool_result, hash:)

                assert message.is_error
              end

              test "format calls context.tool_use with tool_use_id" do
                mock_context = Minitest::Mock.new
                mock_tool_use = Struct.new(:name, :input).new(:test_tool, {})
                mock_context.expect(:tool_use, mock_tool_use, ["tool_123"])

                result = @message.format(mock_context)

                mock_context.verify
                assert_kind_of String, result
              end
            end
          end
        end
      end
    end
  end
end
