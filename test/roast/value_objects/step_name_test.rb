# frozen_string_literal: true

require "test_helper"

module Roast
  module ValueObjects
    class StepNameTest < ActiveSupport::TestCase
      def test_initialization_with_string
        step_name = StepName.new("test_step")
        assert_equal("test_step", step_name.value)
      end

      def test_initialization_strips_whitespace
        step_name = StepName.new("  test_step  ")
        assert_equal("test_step", step_name.value)
      end

      def test_plain_text_detection
        plain_text = StepName.new("this is a plain text prompt")
        assert(plain_text.plain_text?)
        refute(plain_text.file_reference?)
      end

      def test_file_reference_detection
        file_ref = StepName.new("test_step")
        assert(file_ref.file_reference?)
        refute(file_ref.plain_text?)
      end

      def test_to_s_returns_value
        step_name = StepName.new("test_step")
        assert_equal("test_step", step_name.to_s)
      end

      def test_equality
        step1 = StepName.new("test_step")
        step2 = StepName.new("test_step")
        step3 = StepName.new("other_step")

        assert_equal(step1, step2)
        refute_equal(step1, step3)
        refute_equal(step1, "test_step")
        refute_equal(step1, nil)
      end

      def test_eql_method
        step1 = StepName.new("test_step")
        step2 = StepName.new("test_step")

        assert(step1.eql?(step2))
      end

      def test_hash_equality
        step1 = StepName.new("test_step")
        step2 = StepName.new("test_step")
        step3 = StepName.new("other_step")

        assert_equal(step1.hash, step2.hash)
        refute_equal(step1.hash, step3.hash)
      end

      def test_can_be_used_as_hash_key
        hash = {}
        step1 = StepName.new("test_step")
        step2 = StepName.new("test_step")

        hash[step1] = "value"
        assert_equal("value", hash[step2])
      end

      def test_frozen_after_initialization
        step_name = StepName.new("test_step")
        assert(step_name.frozen?)
      end
    end
  end
end
