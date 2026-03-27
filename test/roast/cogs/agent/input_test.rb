# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class InputTest < ActiveSupport::TestCase
        def setup
          @input = Input.new
        end

        test "initialize sets prompts to empty array" do
          assert_equal [], @input.prompts
        end

        test "prompt= sets prompts to single-element array" do
          @input.prompt = "What is 2+2?"

          assert_equal ["What is 2+2?"], @input.prompts
        end

        test "prompts can be set directly" do
          @input.prompts = ["First", "Second"]

          assert_equal ["First", "Second"], @input.prompts
        end

        test "session can be set" do
          @input.session = "session-123"

          assert_equal "session-123", @input.session
        end

        test "validate! raises error when prompts is empty" do
          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "At least one prompt is required", error.message
        end

        test "validate! raises error when any prompt is blank" do
          @input.prompts = ["Valid prompt", "  ", "Another"]

          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "Blank prompts are not allowed", error.message
        end

        test "validate! succeeds when prompts has at least one element" do
          @input.prompt = "What is 2+2?"

          assert_nothing_raised do
            @input.validate!
          end
        end

        test "validate! succeeds with multiple prompts" do
          @input.prompts = ["First", "Second"]

          assert_nothing_raised do
            @input.validate!
          end
        end

        test "coerce sets prompts from string" do
          @input.coerce("What is the meaning of life?")

          assert_equal ["What is the meaning of life?"], @input.prompts
        end

        test "coerce overrides existing prompts" do
          @input.prompt = "Original prompt"
          @input.coerce("New prompt")

          assert_equal ["New prompt"], @input.prompts
        end

        test "coerce does nothing for non-string non-array values" do
          @input.coerce(42)

          assert_equal [], @input.prompts
        end

        test "coerce does nothing for nil" do
          @input.coerce(nil)

          assert_equal [], @input.prompts
        end

        test "coerce with array sets all prompts" do
          @input.coerce(["Main prompt", "Finalizer 1", "Finalizer 2"])

          assert_equal ["Main prompt", "Finalizer 1", "Finalizer 2"], @input.prompts
        end

        test "coerce with single-element array" do
          @input.coerce(["Only prompt"])

          assert_equal ["Only prompt"], @input.prompts
        end

        test "coerce with array converts elements to strings" do
          @input.coerce(["Main prompt", 42, :symbol])

          assert_equal ["Main prompt", "42", "symbol"], @input.prompts
        end

        test "coerce with empty array sets prompts to empty" do
          @input.coerce([])

          assert_equal [], @input.prompts
        end

        test "prompt= overrides all existing prompts" do
          @input.prompts = ["First", "Second", "Third"]
          @input.prompt = "Only"

          assert_equal ["Only"], @input.prompts
        end
      end
    end
  end
end
