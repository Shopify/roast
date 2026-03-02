# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class SessionMessageTest < ActiveSupport::TestCase
              test "extracts session_id from id field" do
                message = SessionMessage.new(
                  type: :session,
                  hash: { id: "abc-123", version: 3, timestamp: "2026-01-01", cwd: "/tmp" },
                )

                assert_equal "abc-123", message.session_id
              end

              test "ignores version, timestamp, and cwd" do
                message = SessionMessage.new(
                  type: :session,
                  hash: { id: "abc-123", version: 3, timestamp: "2026-01-01", cwd: "/tmp" },
                )

                assert message.unparsed.empty?
              end

              test "session_id is nil when id not present" do
                message = SessionMessage.new(type: :session, hash: {})

                assert_nil message.session_id
              end
            end
          end
        end
      end
    end
  end
end
