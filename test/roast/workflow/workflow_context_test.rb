# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class WorkflowContextTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @config_hash = {
          "step1" => { "exit_on_error" => false },
          "step2" => { "exit_on_error" => true },
          "step3" => "simple string value",
          "step4" => { "other_config" => "value" },
        }
        @context_path = "/path/to/context"

        @context = WorkflowContext.new(
          workflow: @workflow,
          config_hash: @config_hash,
          context_path: @context_path,
        )
      end

      def test_initializes_with_required_parameters
        assert_equal(@workflow, @context.workflow)
        assert_equal(@config_hash, @context.config_hash)
        assert_equal(@context_path, @context.context_path)
      end

      def test_context_is_frozen
        assert(@context.frozen?)
      end

      def test_with_workflow_creates_new_context
        new_workflow = mock("new_workflow")
        new_context = @context.with_workflow(new_workflow)

        assert_equal(new_workflow, new_context.workflow)
        assert_equal(@config_hash, new_context.config_hash)
        assert_equal(@context_path, new_context.context_path)
        refute_equal(@context, new_context)
      end

      def test_has_resource_when_workflow_has_resource
        resource = mock("resource")
        @workflow.expects(:respond_to?).with(:resource).returns(true)
        @workflow.expects(:resource).returns(resource)

        assert(@context.has_resource?)
      end

      def test_has_resource_when_workflow_has_no_resource
        @workflow.expects(:respond_to?).with(:resource).returns(true)
        @workflow.expects(:resource).returns(nil)

        refute(@context.has_resource?)
      end

      def test_has_resource_when_workflow_does_not_respond_to_resource
        @workflow.expects(:respond_to?).with(:resource).returns(false)

        refute(@context.has_resource?)
      end

      def test_resource_type_with_resource
        resource = mock("resource")
        resource.expects(:type).returns(:file)
        @workflow.expects(:respond_to?).with(:resource).returns(true)
        @workflow.expects(:resource).returns(resource).twice

        assert_equal(:file, @context.resource_type)
      end

      def test_resource_type_without_resource
        @workflow.expects(:respond_to?).with(:resource).returns(false)

        assert_nil(@context.resource_type)
      end

      def test_step_config_returns_config_when_exists
        config = @context.step_config("step1")
        assert_equal({ "exit_on_error" => false }, config)
      end

      def test_step_config_returns_empty_hash_when_not_exists
        config = @context.step_config("nonexistent")
        assert_equal({}, config)
      end

      def test_exit_on_error_returns_false_when_explicitly_set
        refute(@context.exit_on_error?("step1"))
      end

      def test_exit_on_error_returns_true_when_explicitly_set
        assert(@context.exit_on_error?("step2"))
      end

      def test_exit_on_error_returns_true_by_default_for_string_config
        assert(@context.exit_on_error?("step3"))
      end

      def test_exit_on_error_returns_true_by_default_when_not_specified
        assert(@context.exit_on_error?("step4"))
      end

      def test_exit_on_error_returns_true_for_nonexistent_step
        assert(@context.exit_on_error?("nonexistent"))
      end
    end
  end
end
