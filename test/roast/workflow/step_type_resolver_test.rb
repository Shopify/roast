# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepTypeResolverTest < ActiveSupport::TestCase
      def setup
        @context = mock("context")
      end

      def test_resolves_command_step
        step = "$(echo hello)"
        assert_equal(StepTypeResolver::COMMAND_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_glob_step_without_resource
        step = "*.rb"
        @context.expects(:has_resource?).returns(false)
        assert_equal(StepTypeResolver::GLOB_STEP, StepTypeResolver.resolve(step, @context))
      end

      def test_resolves_string_step_for_glob_with_resource
        step = "*.rb"
        @context.expects(:has_resource?).returns(true)
        assert_equal(StepTypeResolver::STRING_STEP, StepTypeResolver.resolve(step, @context))
      end

      def test_resolves_iteration_step_repeat
        step = { "repeat" => { "until" => "done" } }
        assert_equal(StepTypeResolver::ITERATION_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_iteration_step_each
        step = { "each" => "items", "as" => "item", "steps" => ["process"] }
        assert_equal(StepTypeResolver::ITERATION_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_hash_step
        step = { "var1" => "command1" }
        assert_equal(StepTypeResolver::HASH_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_parallel_step
        step = ["step1", "step2"]
        assert_equal(StepTypeResolver::PARALLEL_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_string_step
        step = "regular_step"
        assert_equal(StepTypeResolver::STRING_STEP, StepTypeResolver.resolve(step))
      end

      def test_command_step_predicate
        assert(StepTypeResolver.command_step?("$(echo test)"))
        refute(StepTypeResolver.command_step?("echo test"))
        refute(StepTypeResolver.command_step?(nil))
        refute(StepTypeResolver.command_step?({}))
      end

      def test_glob_step_predicate_without_context
        assert(StepTypeResolver.glob_step?("*.rb"))
        assert(StepTypeResolver.glob_step?("src/**/*.js"))
        refute(StepTypeResolver.glob_step?("test.rb"))
        refute(StepTypeResolver.glob_step?(nil))
      end

      def test_glob_step_predicate_with_context
        @context.expects(:has_resource?).returns(false)
        assert(StepTypeResolver.glob_step?("*.rb", @context))

        @context.expects(:has_resource?).returns(true)
        refute(StepTypeResolver.glob_step?("*.rb", @context))
      end

      def test_iteration_step_predicate
        assert(StepTypeResolver.iteration_step?({ "repeat" => {} }))
        assert(StepTypeResolver.iteration_step?({ "each" => "items" }))
        refute(StepTypeResolver.iteration_step?({ "var" => "value" }))
        refute(StepTypeResolver.iteration_step?("string"))
        refute(StepTypeResolver.iteration_step?([]))
      end

      def test_conditional_step_predicate
        assert(StepTypeResolver.conditional_step?({ "if" => "condition" }))
        assert(StepTypeResolver.conditional_step?({ "unless" => "condition" }))
        refute(StepTypeResolver.conditional_step?({ "var" => "value" }))
        refute(StepTypeResolver.conditional_step?("string"))
        refute(StepTypeResolver.conditional_step?([]))
      end

      def test_case_step_predicate
        assert(StepTypeResolver.case_step?({ "case" => "expression" }))
        refute(StepTypeResolver.case_step?({ "var" => "value" }))
        refute(StepTypeResolver.case_step?("string"))
        refute(StepTypeResolver.case_step?([]))
      end

      def test_resolves_conditional_step_if
        step = { "if" => "condition", "then" => ["step1"] }
        assert_equal(StepTypeResolver::CONDITIONAL_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_conditional_step_unless
        step = { "unless" => "condition", "then" => ["step1"] }
        assert_equal(StepTypeResolver::CONDITIONAL_STEP, StepTypeResolver.resolve(step))
      end

      def test_resolves_case_step
        step = { "case" => "expression", "when" => { "value1" => ["step1"] } }
        assert_equal(StepTypeResolver::CASE_STEP, StepTypeResolver.resolve(step))
      end

      def test_extract_name_from_string
        assert_equal("test", StepTypeResolver.extract_name("test"))
      end

      def test_extract_name_from_hash
        assert_equal("var1", StepTypeResolver.extract_name({ "var1" => "value" }))
      end

      def test_extract_name_from_array_returns_nil
        assert_nil(StepTypeResolver.extract_name(["step1", "step2"]))
      end

      def test_extract_name_from_unknown_returns_nil
        assert_nil(StepTypeResolver.extract_name(123))
      end
    end
  end
end
