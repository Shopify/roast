# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class UnknownMessageTest < ActiveSupport::TestCase
              test "initialize stores hash in raw" do
                hash = { foo: "bar", baz: 123 }
                message = UnknownMessage.new(type: "unknown", hash: hash.dup)

                assert_equal "bar", message.raw[:foo]
                assert_equal 123, message.raw[:baz]
              end

              test "raw is the same object as hash" do
                hash = { test: "value" }
                message = UnknownMessage.new(type: "unknown", hash:)

                assert_same hash, message.raw
              end

              test "type is preserved" do
                message = UnknownMessage.new(type: "new_type", hash: {})

                assert_equal "new_type", message.type
              end
            end
          end
        end
      end
    end
  end
end
