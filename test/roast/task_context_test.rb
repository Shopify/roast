# frozen_string_literal: true

require "test_helper"

module Roast
  class TaskContextTest < ActiveSupport::TestCase
    setup do
      Fiber[:path] = nil
      EventMonitor.reset!
    end

    teardown do
      Fiber[:path] = nil
    end

    # --- path ---

    test "path returns empty array when no fiber path is set" do
      assert_equal [], TaskContext.path
    end

    test "path returns a dup of the fiber-local path" do
      Fiber[:path] = [:a, :b]

      result = TaskContext.path

      assert_equal [:a, :b], result
      refute_same Fiber[:path], result
    end

    # --- begin ---

    test "begin pushes id onto the fiber path" do
      TaskContext.begin(:step1)

      assert_equal [:step1], Fiber[:path]
    end

    test "begin returns the updated path" do
      result = TaskContext.begin(:step1)

      assert_equal [:step1], result
    end

    test "begin nests paths with successive calls" do
      TaskContext.begin(:outer)
      TaskContext.begin(:inner)

      assert_equal [:outer, :inner], Fiber[:path]
    end

    test "begin emits a begin event" do
      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) && event[:begin] == :my_step
      end

      TaskContext.begin(:my_step)
    end

    test "begin event has the path before the id is pushed" do
      Fiber[:path] = [:existing]

      EventMonitor.expects(:accept).with do |event|
        event.path == [:existing]
      end

      TaskContext.begin(:new_step)
    end

    # --- end ---

    test "end pops the last id from the fiber path" do
      Fiber[:path] = [:a, :b]

      TaskContext.end

      assert_equal [:a], Fiber[:path]
    end

    test "end returns the popped id and remaining path" do
      Fiber[:path] = [:a, :b]

      id, remaining_path = TaskContext.end

      assert_equal :b, id
      assert_equal [:a], remaining_path
    end

    test "end emits an end event with the popped id and remaining path" do
      Fiber[:path] = [:workflow, :step1]

      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) && event[:end] == :step1 && event.path == [:workflow]
      end

      TaskContext.end
    end

    test "end returns nil id when path is empty" do
      id, remaining_path = TaskContext.end

      assert_nil id
      assert_equal [], remaining_path
    end

    # --- begin/end round-trip ---

    test "begin and end are symmetric" do
      TaskContext.begin(:a)
      TaskContext.begin(:b)
      TaskContext.end
      TaskContext.end

      assert_equal [], Fiber[:path]
    end

    # --- fiber isolation ---

    test "path is isolated between fibers with separate storage" do
      Fiber[:path] = [:main_fiber]

      other_path = nil
      Fiber.new(storage: {}) do
        other_path = TaskContext.path
      end.resume

      assert_equal [], other_path
      assert_equal [:main_fiber], Fiber[:path]
    end
  end
end
