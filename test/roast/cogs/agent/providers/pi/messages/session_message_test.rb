# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class SessionMessageTest < ActiveSupport::TestCase
              test "initialize sets session_id from id field" do
                hash = { id: "abc-123", version: 3, cwd: "/tmp", timestamp: "2026-01-01T00:00:00Z" }
                message = SessionMessage.new(type: "session", hash:)

                assert_equal "abc-123", message.session_id
              end

              test "initialize sets version" do
                hash = { id: "abc", version: 3 }
                message = SessionMessage.new(type: "session", hash:)

                assert_equal 3, message.version
              end

              test "initialize sets cwd" do
                hash = { id: "abc", cwd: "/home/user" }
                message = SessionMessage.new(type: "session", hash:)

                assert_equal "/home/user", message.cwd
              end

              test "initialize sets timestamp" do
                hash = { id: "abc", timestamp: "2026-01-01T00:00:00Z" }
                message = SessionMessage.new(type: "session", hash:)

                assert_equal "2026-01-01T00:00:00Z", message.timestamp
              end

              test "initialize removes parsed fields from hash" do
                hash = { id: "abc", version: 3, cwd: "/tmp", timestamp: "2026-01-01T00:00:00Z" }
                SessionMessage.new(type: "session", hash:)

                refute hash.key?(:id)
                refute hash.key?(:version)
                refute hash.key?(:cwd)
                refute hash.key?(:timestamp)
              end

              test "initialize handles missing fields" do
                hash = {}
                message = SessionMessage.new(type: "session", hash:)

                assert_nil message.session_id
                assert_nil message.version
                assert_nil message.cwd
                assert_nil message.timestamp
              end
            end
          end
        end
      end
    end
  end
end
