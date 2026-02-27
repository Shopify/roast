# frozen_string_literal: true

require "test_helper"

module Roast
  class TaskContextTest < ActiveSupport::TestCase
    setup do
      Fiber[:path] = nil
      EventMonitor.reset!
      EventMonitor.stubs(:accept)
    end

    teardown do
      Fiber[:path] = nil
    end

    # --- path ---

    test "path returns empty array when no fiber path is set" do
      assert_equal [], TaskContext.path
    end

    test "path returns a deep dup of the fiber-local path" do
      cog_a = TestCogSupport::TestCog.new(:a, nil)
      cog_b = TestCogSupport::TestCog.new(:b, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: cog_a), TaskContext::PathElement.new(cog: cog_b)]

      result = TaskContext.path

      assert_equal 2, result.length
      refute_same Fiber[:path], result
      refute_same Fiber[:path][0], result[0]
      refute_same Fiber[:path][1], result[1]
    end

    # --- begin_cog ---

    test "begin_cog pushes a cog PathElement onto the fiber path" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      TaskContext.begin_cog(cog)

      assert_equal 1, Fiber[:path].length
      assert_instance_of TaskContext::PathElement, Fiber[:path].first
      assert_equal cog, Fiber[:path].first.cog
      assert_nil Fiber[:path].first.execution_manager
    end

    test "begin_cog returns the updated path" do
      cog = TestCogSupport::TestCog.new(:step1, nil)
      result = TaskContext.begin_cog(cog)

      assert_equal 1, result.length
      assert_equal cog, result.first.cog
    end

    test "begin_cog nests paths with successive calls" do
      outer = TestCogSupport::TestCog.new(:outer, nil)
      inner = TestCogSupport::TestCog.new(:inner, nil)
      TaskContext.begin_cog(outer)
      TaskContext.begin_cog(inner)

      assert_equal 2, Fiber[:path].length
      assert_equal outer, Fiber[:path].first.cog
      assert_equal inner, Fiber[:path].last.cog
    end

    test "begin_cog emits a begin event" do
      cog = TestCogSupport::TestCog.new(:my_step, nil)
      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) &&
          event[:begin].is_a?(TaskContext::PathElement) &&
          event[:begin].cog == cog
      end

      TaskContext.begin_cog(cog)
    end

    test "begin_cog event includes the new element in its path" do
      existing_cog = TestCogSupport::TestCog.new(:existing, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: existing_cog)]

      new_cog = TestCogSupport::TestCog.new(:new_step, nil)
      EventMonitor.expects(:accept).with do |event|
        event.path.length == 2 &&
          event.path.first.cog == existing_cog &&
          event.path.last.cog == new_cog
      end

      TaskContext.begin_cog(new_cog)
    end

    # --- begin_execution_manager ---

    test "begin_execution_manager pushes an execution_manager PathElement onto the fiber path" do
      em = mock("execution_manager")
      TaskContext.begin_execution_manager(em)

      assert_equal 1, Fiber[:path].length
      assert_instance_of TaskContext::PathElement, Fiber[:path].first
      assert_equal em, Fiber[:path].first.execution_manager
      assert_nil Fiber[:path].first.cog
    end

    test "begin_execution_manager returns the updated path" do
      em = mock("execution_manager")
      result = TaskContext.begin_execution_manager(em)

      assert_equal 1, result.length
      assert_equal em, result.first.execution_manager
    end

    test "begin_execution_manager emits a begin event" do
      em = mock("execution_manager")
      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) &&
          event[:begin].is_a?(TaskContext::PathElement) &&
          event[:begin].execution_manager == em
      end

      TaskContext.begin_execution_manager(em)
    end

    # --- end ---

    test "end pops the last element from the fiber path" do
      cog_a = TestCogSupport::TestCog.new(:a, nil)
      cog_b = TestCogSupport::TestCog.new(:b, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: cog_a), TaskContext::PathElement.new(cog: cog_b)]

      TaskContext.end

      assert_equal 1, Fiber[:path].length
      assert_equal cog_a, Fiber[:path].first.cog
    end

    test "end returns the popped element and remaining path" do
      cog_a = TestCogSupport::TestCog.new(:a, nil)
      cog_b = TestCogSupport::TestCog.new(:b, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: cog_a), TaskContext::PathElement.new(cog: cog_b)]

      el, remaining_path = TaskContext.end

      assert_equal cog_b, el.cog
      assert_equal 1, remaining_path.length
      assert_equal cog_a, remaining_path.first.cog
    end

    test "end emits an end event with the ending element" do
      cog_a = TestCogSupport::TestCog.new(:a, nil)
      cog_b = TestCogSupport::TestCog.new(:b, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: cog_a), TaskContext::PathElement.new(cog: cog_b)]

      EventMonitor.expects(:accept).with do |event|
        event.is_a?(Event) &&
          event[:end].is_a?(TaskContext::PathElement) &&
          event[:end].cog == cog_b &&
          event.path.length == 2
      end

      TaskContext.end
    end

    test "end returns nil element when path is empty" do
      el, remaining_path = TaskContext.end

      assert_nil el
      assert_equal [], remaining_path
    end

    # --- begin/end round-trip ---

    test "begin and end are symmetric" do
      cog_a = TestCogSupport::TestCog.new(:a, nil)
      cog_b = TestCogSupport::TestCog.new(:b, nil)
      TaskContext.begin_cog(cog_a)
      TaskContext.begin_cog(cog_b)
      TaskContext.end
      TaskContext.end

      assert_equal [], Fiber[:path]
    end

    # --- fiber isolation ---

    test "path is isolated between fibers with separate storage" do
      cog = TestCogSupport::TestCog.new(:main_fiber, nil)
      Fiber[:path] = [TaskContext::PathElement.new(cog: cog)]

      other_path = nil
      Fiber.new(storage: {}) do
        other_path = TaskContext.path
      end.resume

      assert_equal [], other_path
      assert_equal 1, Fiber[:path].length
      assert_equal cog, Fiber[:path].first.cog
    end
  end
end
