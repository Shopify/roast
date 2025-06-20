# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepOrchestratorTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @step_loader = mock("step_loader")
        @state_manager = mock("state_manager")
        @error_handler = mock("error_handler")
        @workflow_executor = mock("workflow_executor")

        # Mock the config object
        @config = mock("config")
        @config.stubs(:get_step_config).returns({})
        @workflow.stubs(:config).returns(@config)

        @orchestrator = StepOrchestrator.new(
          @workflow,
          @step_loader,
          @state_manager,
          @error_handler,
          @workflow_executor,
        )
      end

      def test_execute_step_with_resource
        step_name = "test_step"
        step_result = "step result"
        resource = mock("resource", type: "file")

        @workflow.expects(:respond_to?).with(:resource).returns(true)
        @workflow.expects(:resource).returns(resource).at_least_once
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)

        @error_handler.expects(:with_error_handling).with(step_name, resource_type: "file", step_config: {}).yields.returns(step_result)

        result = @orchestrator.execute_step(step_name)
        assert_equal(step_result, result)
      end

      def test_execute_step_without_resource
        step_name = "test_step"
        step_result = "step result"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)

        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil, step_config: {}).yields.returns(step_result)

        result = @orchestrator.execute_step(step_name)
        assert_equal(step_result, result)
      end

      def test_execute_step_stores_result_in_workflow_output
        step_name = "test_step"
        step_result = "step result"
        output_hash = {}

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns(output_hash)

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)
        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil, step_config: {}).yields.returns(step_result)

        @orchestrator.execute_step(step_name)
        assert_equal(step_result, output_hash[step_name])
      end

      def test_execute_step_with_exit_on_error_false
        step_name = "test_step"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns("result")

        @state_manager.expects(:save_state)
        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil, step_config: {}).yields.returns("result")

        @orchestrator.execute_step(step_name, exit_on_error: false)
      end

      def test_execute_step_prints_execution_message
        step_name = "test_step"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns("result")

        @state_manager.expects(:save_state)
        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil, step_config: {}).yields.returns("result")

        # Capture stderr output
        original_stderr = $stderr
        $stderr = StringIO.new

        @orchestrator.execute_step(step_name)

        output = $stderr.string
        assert_match(/Executing: test_step \(Resource type: unknown\)/, output)
      ensure
        $stderr = original_stderr
      end

      def test_execute_step_with_different_step_key
        step_name = "This is a prompt with spaces"
        step_key = "prompt_step"
        step_result = "step result"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)
        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil, step_config: {}).yields.returns(step_result)

        result = @orchestrator.execute_step(step_name, step_key: step_key)
        assert_equal(step_result, result)
      end
    end
  end
end
