# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Chat < Cog
      class OutputTest < ActiveSupport::TestCase
        def setup
          @session = Session.new([])
        end

        test "initialize sets session and response" do
          output = Output.new(@session, "Hello, world!")

          assert_same @session, output.session
          assert_equal "Hello, world!", output.response
        end

        test "provides text parsing from response" do
          output = Output.new(@session, "  Test response  \n")

          assert_equal "Test response", output.text
        end

        test "provides line parsing from response" do
          output = Output.new(@session, "  line1  \n  line2  ")

          assert_equal ["line1", "line2"], output.lines
        end

        test "provides JSON parsing from response" do
          output = Output.new(@session, '{"key": "value"}')

          assert_equal({ key: "value" }, output.json!)
        end

        test "provides safe JSON parsing from response" do
          output = Output.new(@session, "not json")

          assert_nil output.json
        end

        test "provides float parsing from response" do
          output = Output.new(@session, "42.5")

          assert_equal 42.5, output.float!
        end

        test "provides safe float parsing from response" do
          output = Output.new(@session, "not a number")

          assert_nil output.float
        end

        test "provides integer parsing from response" do
          output = Output.new(@session, "42")

          assert_equal 42, output.integer!
        end

        test "provides safe integer parsing from response" do
          output = Output.new(@session, "not a number")

          assert_nil output.integer
        end
      end
    end
  end
end
