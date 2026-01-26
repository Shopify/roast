# frozen_string_literal: true

require "test_helper"

module Roast
  class CogInputContextTest < ActiveSupport::TestCase
    def setup
      @context = CogInputContext.new
    end

    test "skip! raises SkipCog without a message" do
      assert_raises(ControlFlow::SkipCog) do
        @context.skip!
      end
    end

    test "skip! raises SkipCog with the provided message" do
      error = assert_raises(ControlFlow::SkipCog) do
        @context.skip!("skipping this cog")
      end
      assert_equal "skipping this cog", error.message
    end

    test "fail! raises FailCog without a message" do
      assert_raises(ControlFlow::FailCog) do
        @context.fail!
      end
    end

    test "fail! raises FailCog with the provided message" do
      error = assert_raises(ControlFlow::FailCog) do
        @context.fail!("cog failed")
      end
      assert_equal "cog failed", error.message
    end

    test "next! raises Next without a message" do
      assert_raises(ControlFlow::Next) do
        @context.next!
      end
    end

    test "next! raises Next with the provided message" do
      error = assert_raises(ControlFlow::Next) do
        @context.next!("moving to next iteration")
      end
      assert_equal "moving to next iteration", error.message
    end

    test "break! raises Break without a message" do
      assert_raises(ControlFlow::Break) do
        @context.break!
      end
    end

    test "break! raises Break with the provided message" do
      error = assert_raises(ControlFlow::Break) do
        @context.break!("breaking out of loop")
      end
      assert_equal "breaking out of loop", error.message
    end
  end
end
