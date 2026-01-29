# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class UnknownMessageTest < ActiveSupport::TestCase
              def setup
                @hash = { foo: "bar", baz: 123 }
                @message = UnknownMessage.new(type: :unknown, hash: @hash.dup)
              end

              test "initialize stores hash in raw" do
                assert_equal @hash, @message.raw
              end

              test "raw contains all fields from hash" do
                assert_equal "bar", @message.raw[:foo]
                assert_equal 123, @message.raw[:baz]
              end

              test "raw is the same object as hash passed to initialize" do
                hash = { test: "value" }
                message = UnknownMessage.new(type: :unknown, hash:)

                assert_same hash, message.raw
              end
            end
          end
        end
      end
    end
  end
end
