# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class StackTest < ActiveSupport::TestCase
      def setup
        @stack = Stack.new
      end

      test "initialize creates empty stack" do
        assert @stack.empty?
        assert_equal 0, @stack.size
      end

      test "push adds items to the stack" do
        @stack.push(:first)
        @stack.push(:second)

        assert_equal 2, @stack.size
        refute @stack.empty?
      end

      test "pop removes and returns items in FIFO order" do
        @stack.push(:first)
        @stack.push(:second)
        @stack.push(:third)

        assert_equal :first, @stack.pop
        assert_equal :second, @stack.pop
        assert_equal :third, @stack.pop
      end

      test "pop returns nil when stack is empty" do
        assert_nil @stack.pop
      end

      test "last returns the most recently pushed item" do
        @stack.push(:first)
        @stack.push(:second)

        assert_equal :second, @stack.last
      end

      test "each iterates over all items" do
        @stack.push(:first)
        @stack.push(:second)

        items = []
        @stack.each { |item| items << item }

        assert_equal [:first, :second], items
      end

      test "map transforms all items" do
        @stack.push(1)
        @stack.push(2)
        @stack.push(3)

        result = @stack.map { |n| n * 2 }

        assert_equal [2, 4, 6], result
      end
    end
  end
end
