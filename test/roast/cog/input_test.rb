# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class InputTest < ActiveSupport::TestCase
      def setup
        @input = Input.new
      end

      test "validate! raises NotImplementedError" do
        assert_raises(NotImplementedError) do
          @input.validate!
        end
      end

      test "coerce accepts any argument" do
        assert_nothing_raised do
          @input.coerce("some value")
        end
      end

      test "coerce accepts nil" do
        assert_nothing_raised do
          @input.coerce(nil)
        end
      end

      test "coerce accepts complex objects" do
        assert_nothing_raised do
          @input.coerce({ key: "value", nested: [1, 2, 3] })
        end
      end

      test "coerce_ran? returns false initially" do
        refute @input.send(:coerce_ran?)
      end

      test "coerce_ran? returns true after coerce is called" do
        @input.coerce("value")

        assert @input.send(:coerce_ran?)
      end

      test "coerce_ran? persists across multiple calls" do
        @input.coerce("first")

        assert @input.send(:coerce_ran?)

        @input.coerce("second")

        assert @input.send(:coerce_ran?)
      end

      test "subclass can override validate!" do
        subclass = Class.new(Input) do
          def validate!
            raise Input::InvalidInputError, "custom validation failed"
          end
        end

        input = subclass.new

        error = assert_raises(Input::InvalidInputError) do
          input.validate!
        end

        assert_equal "custom validation failed", error.message
      end

      test "subclass can override coerce" do
        subclass = Class.new(Input) do
          attr_reader :coerced_value

          def coerce(input_return_value)
            super
            @coerced_value = input_return_value.upcase
          end
        end

        input = subclass.new
        input.coerce("test")

        assert_equal "TEST", input.coerced_value
        assert input.send(:coerce_ran?)
      end

      test "subclass can use coerce_ran? to adapt validation behavior" do
        subclass = Class.new(Input) do
          attr_accessor :optional_field

          def validate!
            if optional_field.nil? && !coerce_ran?
              raise Input::InvalidInputError, "optional_field must be set before coercion"
            end
          end

          def coerce(input_return_value)
            super
            @optional_field = input_return_value
          end
        end

        input = subclass.new

        # First validation fails when optional_field is nil and coerce hasn't run
        error = assert_raises(Input::InvalidInputError) do
          input.validate!
        end
        assert_equal "optional_field must be set before coercion", error.message

        # After coerce runs, validation passes even with nil
        input.coerce(nil)
        assert_nothing_raised do
          input.validate!
        end
      end
    end
  end
end
