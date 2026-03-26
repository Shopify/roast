# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolCallMessageTest < ActiveSupport::TestCase
              test "format returns BASH with command for bash tool" do
                msg = ToolCallMessage.new(id: "1", name: "bash", arguments: { command: "ls -la" })
                assert_equal "BASH ls -la", msg.format
              end

              test "format returns READ with path for read tool" do
                msg = ToolCallMessage.new(id: "1", name: "read", arguments: { path: "/tmp/test.rb" })
                assert_equal "READ /tmp/test.rb", msg.format
              end

              test "format returns EDIT with path for edit tool" do
                msg = ToolCallMessage.new(id: "1", name: "edit", arguments: { path: "/tmp/test.rb" })
                assert_equal "EDIT /tmp/test.rb", msg.format
              end

              test "format returns WRITE with path for write tool" do
                msg = ToolCallMessage.new(id: "1", name: "write", arguments: { path: "/tmp/test.rb" })
                assert_equal "WRITE /tmp/test.rb", msg.format
              end

              test "format returns GREP with pattern for grep tool" do
                msg = ToolCallMessage.new(id: "1", name: "grep", arguments: { pattern: "foo", path: "." })
                assert_equal "GREP foo .", msg.format
              end

              test "format returns FIND with pattern for find tool" do
                msg = ToolCallMessage.new(id: "1", name: "find", arguments: { pattern: "*.rb", path: "." })
                assert_equal "FIND *.rb .", msg.format
              end

              test "format returns LS with path for ls tool" do
                msg = ToolCallMessage.new(id: "1", name: "ls", arguments: { path: "/tmp" })
                assert_equal "LS /tmp", msg.format
              end

              test "format returns TOOL with name and args for unknown tools" do
                msg = ToolCallMessage.new(id: "1", name: "custom_tool", arguments: { key: "value" })
                assert_equal "TOOL [custom_tool] #{{ key: "value" }.inspect}", msg.format
              end

              test "format returns nil when name is nil" do
                msg = ToolCallMessage.new(id: "1", name: nil, arguments: {})
                assert_nil msg.format
              end
            end
          end
        end
      end
    end
  end
end
