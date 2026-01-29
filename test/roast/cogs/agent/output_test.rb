# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class OutputTest < ActiveSupport::TestCase
        # Test implementation that sets response like real subclasses would
        class TestOutput < Output
          def initialize(response:, session: nil, stats: nil)
            super()
            @response = response
            @session = session
            @stats = stats
          end
        end

        test "provides text parsing from response" do
          output = TestOutput.new(response: "  Test response  \n")

          assert_equal "Test response", output.text
        end

        test "provides line parsing from response" do
          output = TestOutput.new(response: "  line1  \n  line2  ")

          assert_equal ["line1", "line2"], output.lines
        end

        test "provides JSON parsing from response" do
          output = TestOutput.new(response: '{"key": "value"}')

          assert_equal({ key: "value" }, output.json!)
        end

        test "provides safe JSON parsing from response" do
          output = TestOutput.new(response: "not json")

          assert_nil output.json
        end

        test "provides float parsing from response" do
          output = TestOutput.new(response: "42.5")

          assert_equal 42.5, output.float!
        end

        test "provides safe float parsing from response" do
          output = TestOutput.new(response: "not a number")

          assert_nil output.float
        end

        test "provides integer parsing from response" do
          output = TestOutput.new(response: "42")

          assert_equal 42, output.integer!
        end

        test "provides safe integer parsing from response" do
          output = TestOutput.new(response: "not a number")

          assert_nil output.integer
        end
      end
    end
  end
end
