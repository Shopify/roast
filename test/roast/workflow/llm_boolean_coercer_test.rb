# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class LlmBooleanCoercerTest < ActiveSupport::TestCase
      def test_coerces_explicit_true_values
        assert_equal(true, LlmBooleanCoercer.coerce("yes"))
        assert_equal(true, LlmBooleanCoercer.coerce("Yes"))
        assert_equal(true, LlmBooleanCoercer.coerce("YES"))
        assert_equal(true, LlmBooleanCoercer.coerce("y"))
        assert_equal(true, LlmBooleanCoercer.coerce("true"))
        assert_equal(true, LlmBooleanCoercer.coerce("t"))
        assert_equal(true, LlmBooleanCoercer.coerce("1"))
      end

      def test_coerces_explicit_false_values
        assert_equal(false, LlmBooleanCoercer.coerce("no"))
        assert_equal(false, LlmBooleanCoercer.coerce("No"))
        assert_equal(false, LlmBooleanCoercer.coerce("NO"))
        assert_equal(false, LlmBooleanCoercer.coerce("n"))
        assert_equal(false, LlmBooleanCoercer.coerce("false"))
        assert_equal(false, LlmBooleanCoercer.coerce("f"))
        assert_equal(false, LlmBooleanCoercer.coerce("0"))
      end

      def test_preserves_actual_boolean_values
        assert_equal(true, LlmBooleanCoercer.coerce(true))
        assert_equal(false, LlmBooleanCoercer.coerce(false))
      end

      def test_treats_nil_as_false
        assert_equal(false, LlmBooleanCoercer.coerce(nil))
      end

      def test_coerces_affirmative_phrases_to_true
        assert_equal(true, LlmBooleanCoercer.coerce("I think the answer is yes"))
        assert_equal(true, LlmBooleanCoercer.coerce("That is correct"))
        assert_equal(true, LlmBooleanCoercer.coerce("Absolutely right"))
        assert_equal(true, LlmBooleanCoercer.coerce("I agree with that"))
        assert_equal(true, LlmBooleanCoercer.coerce("That is definitely true"))
      end

      def test_coerces_negative_phrases_to_false
        assert_equal(false, LlmBooleanCoercer.coerce("I disagree with that statement"))
        assert_equal(false, LlmBooleanCoercer.coerce("That is incorrect"))
        assert_equal(false, LlmBooleanCoercer.coerce("I disagree"))
        assert_equal(false, LlmBooleanCoercer.coerce("That's wrong"))
        assert_equal(false, LlmBooleanCoercer.coerce("Never"))
      end

      def test_handles_ambiguous_responses
        _, err = capture_io do
          assert_equal(false, LlmBooleanCoercer.coerce("Yes, but actually no"))
          assert_equal(false, LlmBooleanCoercer.coerce("Maybe"))
          assert_equal(false, LlmBooleanCoercer.coerce("I'm not sure"))
        end

        assert_match(/contains both affirmative and negative terms/, err)
        assert_match(/no clear boolean indicators found/, err)
      end
    end
  end
end
