# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class InputTest < ActiveSupport::TestCase
        def setup
          @input = Input.new
        end

        test "initialize sets prompt to nil" do
          assert_nil @input.prompt
        end

        test "prompt can be set" do
          @input.prompt = "What is 2+2?"

          assert_equal "What is 2+2?", @input.prompt
        end

        test "session can be set" do
          @input.session = "session-123"

          assert_equal "session-123", @input.session
        end

        test "validate! raises error when prompt is nil" do
          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'prompt' is required", error.message
        end

        test "validate! raises error when prompt is empty string" do
          @input.prompt = ""

          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'prompt' is required", error.message
        end

        test "validate! raises error when prompt is whitespace only" do
          @input.prompt = "   "

          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'prompt' is required", error.message
        end

        test "validate! succeeds when prompt is present" do
          @input.prompt = "What is 2+2?"

          assert_nothing_raised do
            @input.validate!
          end
        end

        test "coerce sets prompt from string" do
          @input.coerce("What is the meaning of life?")

          assert_equal "What is the meaning of life?", @input.prompt
        end

        test "coerce does not override existing prompt" do
          @input.prompt = "Original prompt"
          @input.coerce("New prompt")

          assert_equal "Original prompt", @input.prompt
        end

        test "coerce does nothing for non-string values" do
          @input.coerce(42)

          assert_nil @input.prompt
        end

        test "coerce does nothing for nil" do
          @input.coerce(nil)

          assert_nil @input.prompt
        end

        test "valid_prompt! returns prompt when present" do
          @input.prompt = "Test prompt"

          assert_equal "Test prompt", @input.valid_prompt!
        end

        test "valid_prompt! raises error when prompt is nil" do
          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.valid_prompt!
          end

          assert_equal "'prompt' is required", error.message
        end
      end
    end
  end
end
