# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepFinderTest < ActiveSupport::TestCase
      def setup
        @steps = ["step1", { "var1" => "step2" }, ["step3", "step4"]]
        @finder = StepFinder.new(@steps)
      end

      def test_initializes_with_steps
        assert_equal(@steps, @finder.steps)
      end

      def test_initializes_with_empty_array_when_nil
        finder = StepFinder.new(nil)
        assert_equal([], finder.steps)
      end

      def test_finds_index_of_simple_string_steps
        steps = ["step1", "step2", "step3"]
        finder = StepFinder.new(steps)
        assert_equal(0, finder.find_index("step1"))
        assert_equal(1, finder.find_index("step2"))
        assert_equal(2, finder.find_index("step3"))
      end

      def test_finds_index_of_hash_steps
        steps = ["step1", { "var1" => "step2" }, { "var2" => "step3" }]
        finder = StepFinder.new(steps)
        assert_equal(1, finder.find_index("var1"))
        assert_equal(2, finder.find_index("var2"))
      end

      def test_finds_index_within_parallel_steps
        steps = ["step1", ["step2", "step3"], "step4"]
        finder = StepFinder.new(steps)
        assert_equal(1, finder.find_index("step2"))
        assert_equal(1, finder.find_index("step3"))
        assert_equal(2, finder.find_index("step4"))
      end

      def test_finds_index_of_hash_within_parallel_steps
        steps = ["step1", [{ "var1" => "cmd1" }, { "var2" => "cmd2" }], "step3"]
        finder = StepFinder.new(steps)
        assert_equal(1, finder.find_index("var1"))
        assert_equal(1, finder.find_index("var2"))
      end

      def test_finds_index_with_custom_steps_array
        custom_steps = ["custom1", "custom2"]
        assert_equal(1, @finder.find_index("custom2", custom_steps))
      end

      def test_returns_nil_for_nonexistent_steps
        assert_nil(@finder.find_index("nonexistent"))
      end

      def test_extract_name_from_string
        assert_equal("step1", @finder.extract_name("step1"))
      end

      def test_extract_name_from_hash
        assert_equal("var1", @finder.extract_name({ "var1" => "command" }))
      end

      def test_extract_name_from_array
        step = ["step1", { "var2" => "cmd" }, "step3"]
        expected = ["step1", "var2", "step3"]
        assert_equal(expected, @finder.extract_name(step))
      end

      def test_finds_by_extracted_name_with_nested_arrays
        steps = ["step1", { "each" => ["item1", "item2", "item3"] }]
        finder = StepFinder.new(steps)
        assert_equal(1, finder.find_index("each"))
      end

      def test_class_method_convenience
        steps = ["step1", "step2"]
        assert_equal(1, StepFinder.find_index(steps, "step2"))
      end

      def test_complex_nested_structure
        steps = [
          "simple",
          { "hash_step" => "command" },
          ["parallel1", { "parallel_hash" => "cmd" }],
          { "nested" => { "substeps" => ["sub1", "sub2"] } },
        ]
        finder = StepFinder.new(steps)

        assert_equal(0, finder.find_index("simple"))
        assert_equal(1, finder.find_index("hash_step"))
        assert_equal(2, finder.find_index("parallel1"))
        assert_equal(2, finder.find_index("parallel_hash"))
        assert_equal(3, finder.find_index("nested"))
      end
    end
  end
end
