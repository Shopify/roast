# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepExecutorRegistryTest < ActiveSupport::TestCase
      class TestExecutor
        def initialize(workflow_executor)
          @workflow_executor = workflow_executor
        end
      end

      class AnotherTestExecutor
        def initialize(workflow_executor)
          @workflow_executor = workflow_executor
        end
      end

      class CustomStep; end
      class InheritedStep < CustomStep; end

      def setup
        @workflow_executor = mock("workflow_executor")
        # Clear the registry before each test
        StepExecutorRegistry.clear!
      end

      def teardown
        # Clean up after tests
        StepExecutorRegistry.clear!
      end

      def test_register_and_retrieve_executor
        StepExecutorRegistry.register(String, TestExecutor)

        executor = StepExecutorRegistry.for("test", @workflow_executor)
        assert_instance_of(TestExecutor, executor)
      end

      def test_register_multiple_executors
        StepExecutorRegistry.register(String, TestExecutor)
        StepExecutorRegistry.register(Hash, AnotherTestExecutor)

        string_executor = StepExecutorRegistry.for("test", @workflow_executor)
        hash_executor = StepExecutorRegistry.for({}, @workflow_executor)

        assert_instance_of(TestExecutor, string_executor)
        assert_instance_of(AnotherTestExecutor, hash_executor)
      end

      def test_raises_error_for_unknown_step_type
        error = assert_raises(StepExecutorRegistry::UnknownStepTypeError) do
          StepExecutorRegistry.for(Object.new, @workflow_executor)
        end

        assert_match(/No executor registered for step type: Object/, error.message)
      end

      def test_register_with_matcher
        matcher = ->(step) { step.is_a?(String) && step.start_with?("custom:") }
        StepExecutorRegistry.register_with_matcher(matcher, TestExecutor)

        executor = StepExecutorRegistry.for("custom:step", @workflow_executor)
        assert_instance_of(TestExecutor, executor)
      end

      def test_class_registration_takes_precedence_over_matcher
        StepExecutorRegistry.register(String, AnotherTestExecutor)

        matcher = ->(step) { step.is_a?(String) && step.start_with?("special:") }
        StepExecutorRegistry.register_with_matcher(matcher, TestExecutor)

        regular_executor = StepExecutorRegistry.for("regular", @workflow_executor)
        special_executor = StepExecutorRegistry.for("special:step", @workflow_executor)

        # Class registration takes precedence, so both get AnotherTestExecutor
        assert_instance_of(AnotherTestExecutor, regular_executor)
        assert_instance_of(AnotherTestExecutor, special_executor)
      end

      def test_inheritance_lookup
        StepExecutorRegistry.register(CustomStep, TestExecutor)

        executor = StepExecutorRegistry.for(InheritedStep.new, @workflow_executor)
        assert_instance_of(TestExecutor, executor)
      end

      def test_clear_removes_all_registrations
        StepExecutorRegistry.register(String, TestExecutor)
        StepExecutorRegistry.register(Hash, AnotherTestExecutor)

        StepExecutorRegistry.clear!

        assert_raises(StepExecutorRegistry::UnknownStepTypeError) do
          StepExecutorRegistry.for("test", @workflow_executor)
        end
      end

      def test_registered_executors_returns_copy
        StepExecutorRegistry.register(String, TestExecutor)
        StepExecutorRegistry.register(Hash, AnotherTestExecutor)

        executors = StepExecutorRegistry.registered_executors

        assert_equal(TestExecutor, executors[String])
        assert_equal(AnotherTestExecutor, executors[Hash])

        # Verify it's a copy
        executors[Array] = TestExecutor
        refute(StepExecutorRegistry.registered_executors.key?(Array))
      end

      def test_executor_receives_workflow_executor_in_constructor
        StepExecutorRegistry.register(String, TestExecutor)

        TestExecutor.expects(:new).with(@workflow_executor).returns(mock("executor"))

        StepExecutorRegistry.for("test", @workflow_executor)
      end

      def test_multiple_matchers_first_match_wins
        matcher1 = ->(step) { step.is_a?(String) && step.include?("test") }
        matcher2 = ->(step) { step.is_a?(String) && step.include?("es") }

        StepExecutorRegistry.register_with_matcher(matcher1, TestExecutor)
        StepExecutorRegistry.register_with_matcher(matcher2, AnotherTestExecutor)

        executor = StepExecutorRegistry.for("test", @workflow_executor)
        assert_instance_of(TestExecutor, executor)
      end

      def test_class_registration_overrides_previous
        StepExecutorRegistry.register(String, TestExecutor)
        StepExecutorRegistry.register(String, AnotherTestExecutor)

        executor = StepExecutorRegistry.for("test", @workflow_executor)
        assert_instance_of(AnotherTestExecutor, executor)
      end
    end
  end
end
