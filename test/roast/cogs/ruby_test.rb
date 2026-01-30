# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Ruby < Cog
      class InputTest < ActiveSupport::TestCase
        def setup
          @input = Input.new
        end

        # validate! tests
        test "validate! raises error when value is nil and coerce has not run" do
          assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end
        end

        test "validate! succeeds when value is set" do
          @input.value = "test"

          assert_nothing_raised do
            @input.validate!
          end
        end

        test "validate! succeeds when value is nil but coerce has run" do
          @input.coerce(nil)

          assert_nothing_raised do
            @input.validate!
          end
        end

        # coerce tests
        test "coerce sets value from input return value" do
          @input.coerce("hello world")

          assert_equal "hello world", @input.value
        end

        test "coerce accepts any Ruby object" do
          object = { key: "value", count: 42 }
          @input.coerce(object)

          assert_same object, @input.value
        end
      end

      class OutputTest < ActiveSupport::TestCase
        # Constructor tests
        test "initialize sets value" do
          output = Output.new("test value")

          assert_equal "test value", output.value
        end

        # [] bracket access tests
        test "bracket access returns hash value" do
          output = Output.new({ name: "Alice", age: 30 })

          assert_equal "Alice", output[:name]
          assert_equal 30, output[:age]
        end

        # call tests
        test "call invokes value when it is a Proc" do
          output = Output.new(->(x) { x * 2 })

          assert_equal 10, output.call(5)
        end

        test "call passes block to Proc value" do
          output = Output.new(->(items, &block) { items.map(&block) })

          assert_equal [2, 4, 6], output.call([1, 2, 3]) { |n| n * 2 }
        end

        test "call invokes Proc from hash when given symbol key" do
          output = Output.new({ double: ->(_key, x) { x * 2 } })

          assert_equal 10, output.call(:double, 5)
        end

        test "call raises ArgumentError when value is hash and first arg is not symbol" do
          output = Output.new({ key: "value" })

          assert_raises(ArgumentError) do
            output.call("not a symbol")
          end
        end

        test "call raises NoMethodError when hash key is not a Proc" do
          output = Output.new({ key: "not a proc" })

          assert_raises(NoMethodError) do
            output.call(:key)
          end
        end

        # method_missing delegation tests
        test "method_missing delegates to value when value responds to method" do
          output = Output.new("hello world")

          assert_equal "HELLO WORLD", output.upcase
          assert_equal 11, output.length
        end

        test "method_missing accesses hash key when value is hash" do
          output = Output.new({ name: "Bob", score: 100 })

          assert_equal "Bob", output.name
          assert_equal 100, output.score
        end

        test "method_missing calls Proc in hash with arguments" do
          output = Output.new({ greet: ->(name) { "Hello, #{name}!" } })

          assert_equal "Hello, World!", output.greet("World")
        end

        test "method_missing raises NoMethodError for unknown method" do
          output = Output.new("test")

          assert_raises(NoMethodError) do
            output.nonexistent_method
          end
        end

        # respond_to_missing? tests
        test "respond_to? returns true for methods on value" do
          output = Output.new("hello")

          assert output.respond_to?(:upcase)
          assert output.respond_to?(:length)
        end

        test "respond_to? returns true for hash keys" do
          output = Output.new({ name: "Alice" })

          assert output.respond_to?(:name)
        end

        test "respond_to? returns false for unknown methods" do
          output = Output.new("test")

          refute output.respond_to?(:nonexistent_method)
        end

        test "respond_to? returns false for hash key that does not exist" do
          output = Output.new({ name: "Alice" })

          refute output.respond_to?(:missing_key)
        end
      end

      class ExecuteTest < ActiveSupport::TestCase
        test "execute returns Output with input value" do
          cog = Ruby.new(:test_cog, ->(_input) {})
          input = Input.new
          input.value = { name: "test", count: 42 }

          output = cog.execute(input)

          assert_instance_of Output, output
          assert_equal({ name: "test", count: 42 }, output.value)
        end

        test "run! executes Ruby code and returns result in output" do
          cog = Ruby.new(:compute_cog, ->(_input, _scope, _index) { [1, 2, 3, 4, 5].map { |n| n * 2 }.sum })

          run_cog(cog)

          assert cog.succeeded?
          assert_equal 30, cog.output.value
        end
      end
    end
  end
end
