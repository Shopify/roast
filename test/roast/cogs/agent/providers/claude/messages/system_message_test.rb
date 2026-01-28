# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class SystemMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { message: "System prompt", model: "claude-3-opus" }
                @message = SystemMessage.new(type: :system, hash: @hash.dup)
              end

              test "initialize sets message from hash" do
                assert_equal "System prompt", @message.message
              end

              test "initialize sets model from hash" do
                assert_equal "claude-3-opus", @message.model
              end

              test "initialize removes message from hash" do
                hash = { message: "test" }
                SystemMessage.new(type: :system, hash:)

                refute hash.key?(:message)
              end

              test "initialize removes model from hash" do
                hash = { model: "test" }
                SystemMessage.new(type: :system, hash:)

                refute hash.key?(:model)
              end

              test "initialize removes ignored fields from hash" do
                hash = {
                  message: "test",
                  subtype: "info",
                  cwd: "/tmp",
                  tools: [],
                  mcp_servers: [],
                  permissionMode: "strict",
                  slash_commands: [],
                  apiKeySource: "env",
                  claude_code_version: "1.0",
                  output_style: "json",
                  agents: [],
                  skills: [],
                  plugins: [],
                  hook_name: "test",
                  hook_event: "start",
                  stdout: "output",
                  stderr: "error",
                  exit_code: 0,
                }
                SystemMessage.new(type: :system, hash:)

                refute hash.key?(:subtype)
                refute hash.key?(:cwd)
                refute hash.key?(:tools)
                refute hash.key?(:mcp_servers)
                refute hash.key?(:permissionMode)
                refute hash.key?(:slash_commands)
                refute hash.key?(:apiKeySource)
                refute hash.key?(:claude_code_version)
                refute hash.key?(:output_style)
                refute hash.key?(:agents)
                refute hash.key?(:skills)
                refute hash.key?(:plugins)
                refute hash.key?(:hook_name)
                refute hash.key?(:hook_event)
                refute hash.key?(:stdout)
                refute hash.key?(:stderr)
                refute hash.key?(:exit_code)
              end

              test "initialize allows nil message" do
                hash = { model: "claude-3-opus" }
                message = SystemMessage.new(type: :system, hash:)

                assert_nil message.message
              end

              test "initialize allows nil model" do
                hash = { message: "test" }
                message = SystemMessage.new(type: :system, hash:)

                assert_nil message.model
              end
            end
          end
        end
      end
    end
  end
end
