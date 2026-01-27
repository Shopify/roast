# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ToolUseMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { name: "TestTool", id: "tool_123", input: { arg: "value" } }
                @message = ToolUseMessage.new(type: :tool_use, hash: @hash.dup)
              end

              test "initialize sets name as symbol" do
                assert_equal :testtool, @message.name
              end

              test "initialize converts name to lowercase" do
                hash = { name: "MyTool" }
                message = ToolUseMessage.new(type: :tool_use, hash:)

                assert_equal :mytool, message.name
              end

              test "initialize sets id from hash" do
                assert_equal "tool_123", @message.id
              end

              test "initialize sets input from hash" do
                assert_equal({ arg: "value" }, @message.input)
              end

              test "initialize removes name from hash" do
                hash = { name: "test" }
                ToolUseMessage.new(type: :tool_use, hash:)

                refute hash.key?(:name)
              end

              test "initialize removes id from hash" do
                hash = { id: "123" }
                ToolUseMessage.new(type: :tool_use, hash:)

                refute hash.key?(:id)
              end

              test "initialize removes input from hash" do
                hash = { input: {} }
                ToolUseMessage.new(type: :tool_use, hash:)

                refute hash.key?(:input)
              end

              test "initialize removes role from hash" do
                hash = { role: :assistant }
                ToolUseMessage.new(type: :tool_use, hash:)

                refute hash.key?(:role)
              end

              test "initialize sets name to unknown when nil" do
                hash = { name: nil }
                message = ToolUseMessage.new(type: :tool_use, hash:)

                assert_equal :unknown, message.name
              end

              test "initialize sets input to empty hash when nil" do
                hash = { name: "test" }
                message = ToolUseMessage.new(type: :tool_use, hash:)

                assert_equal({}, message.input)
              end

              test "initialize sets input to empty hash when not provided" do
                hash = { name: "test", input: nil }
                message = ToolUseMessage.new(type: :tool_use, hash:)

                assert_equal({}, message.input)
              end

              test "format creates ToolUse and calls format" do
                context = Object.new
                result = @message.format(context)

                assert_kind_of String, result
              end
            end
          end
        end
      end
    end
  end
end
