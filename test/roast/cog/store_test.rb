# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class StoreTest < ActiveSupport::TestCase
      def setup
        @store = Store.new
        @cog1 = Cog.new(:test_cog, ->(_input) { "result" })
        @cog2 = Cog.new(:another_cog, ->(_input) { "result2" })
      end

      test "insert adds cog to store" do
        result = @store.insert(@cog1)

        assert_equal @cog1, result
        assert_equal @cog1, @store.store[:test_cog]
      end

      test "insert multiple cogs with different names" do
        @store.insert(@cog1)
        @store.insert(@cog2)

        assert_equal @cog1, @store.store[:test_cog]
        assert_equal @cog2, @store.store[:another_cog]
        assert_equal 2, @store.store.size
      end

      test "insert raises CogAlreadyDefinedError for duplicate cog name" do
        @store.insert(@cog1)

        duplicate_cog = Cog.new(:test_cog, ->(_input) { "different result" })

        error = assert_raises(Store::CogAlreadyDefinedError) do
          @store.insert(duplicate_cog)
        end

        assert_equal "test_cog", error.message
      end

      test "[] delegates to store hash" do
        @store.insert(@cog1)

        assert_equal @cog1, @store[:test_cog]
      end

      test "[] returns nil for non-existent key" do
        assert_nil @store[:non_existent]
      end

      test "key? delegates to store hash" do
        @store.insert(@cog1)

        assert @store.key?(:test_cog)
        refute @store.key?(:non_existent)
      end

      test "key? returns false for empty store" do
        refute @store.key?(:anything)
      end

      test "insert returns the cog" do
        result = @store.insert(@cog1)

        assert_same @cog1, result
      end
    end
  end
end
