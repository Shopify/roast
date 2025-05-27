# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_orchestrator"

module Roast
  module Workflow
    class StepOrchestratorTest < Minitest::Test
      def setup
        @workflow = mock("workflow")
        @step_loader = mock("step_loader")
        @state_manager = mock("state_manager")
        @error_handler = mock("error_handler")
        @workflow_executor = mock("workflow_executor")

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
        @step_loader.expects(:load).with(step_name).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)

        @error_handler.expects(:with_error_handling).with(step_name, resource_type: "file").yields.returns(step_result)

        result = @orchestrator.execute_step(step_name)
        assert_equal(step_result, result)
      end

      def test_execute_step_without_resource
        step_name = "test_step"
        step_result = "step result"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).with(step_name).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)

        @error_handler.expects(:with_error_handling).with(step_name, resource_type: nil).yields.returns(step_result)

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
        @step_loader.expects(:load).with(step_name).returns(step_object)
        step_object.expects(:call).returns(step_result)

        @state_manager.expects(:save_state).with(step_name, step_result)
        @error_handler.expects(:with_error_handling).yields.returns("result")

        @orchestrator.execute_step(step_name)
        assert_equal(step_result, output_hash[step_name])
      end

      def test_execute_step_with_exit_on_error_false
        step_name = "test_step"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).with(step_name).returns(step_object)
        step_object.expects(:call).returns("result")

        @state_manager.expects(:save_state)
        @error_handler.expects(:with_error_handling).yields.returns("result")

        @orchestrator.execute_step(step_name, exit_on_error: false)
      end

      def test_execute_steps_with_string_step
        step = "test_step"
        executor = mock("executor")

        StepExecutorFactory.expects(:for).with(step, @workflow_executor).returns(executor)
        executor.expects(:execute).with(step)

        @workflow.expects(:pause_step_name).returns(nil)

        @orchestrator.execute_steps([step])
      end

      def test_execute_steps_with_hash_step
        step = { "name" => "command" }
        executor = mock("executor")

        StepExecutorFactory.expects(:for).with(step, @workflow_executor).returns(executor)
        executor.expects(:execute).with(step)

        @orchestrator.execute_steps([step])
      end

      def test_execute_steps_with_array_step
        step = ["step1", "step2"]
        executor = mock("executor")

        StepExecutorFactory.expects(:for).with(step, @workflow_executor).returns(executor)
        executor.expects(:execute).with(step)

        @orchestrator.execute_steps([step])
      end

      def test_execute_steps_with_pause
        step = "pause_here"
        executor = mock("executor")

        StepExecutorFactory.expects(:for).with(step, @workflow_executor).returns(executor)
        executor.expects(:execute).with(step)

        @workflow.expects(:pause_step_name).returns("pause_here")

        # We can't easily test binding.irb, so we'll stub it
        Kernel.expects(:binding).returns(mock("binding", irb: nil))

        @orchestrator.execute_steps([step])
      end

      def test_execute_steps_multiple_steps
        step1 = "step1"
        step2 = { "name" => "command" }
        step3 = ["parallel1", "parallel2"]

        executor1 = mock("executor1")
        executor2 = mock("executor2")
        executor3 = mock("executor3")

        StepExecutorFactory.expects(:for).with(step1, @workflow_executor).returns(executor1)
        StepExecutorFactory.expects(:for).with(step2, @workflow_executor).returns(executor2)
        StepExecutorFactory.expects(:for).with(step3, @workflow_executor).returns(executor3)

        executor1.expects(:execute).with(step1)
        executor2.expects(:execute).with(step2)
        executor3.expects(:execute).with(step3)

        @workflow.stubs(:pause_step_name).returns(nil)

        @orchestrator.execute_steps([step1, step2, step3])
      end

      def test_execute_step_prints_execution_message
        step_name = "test_step"

        @workflow.expects(:respond_to?).with(:resource).returns(false)
        @workflow.expects(:output).returns({})

        step_object = mock("step_object")
        @step_loader.expects(:load).with(step_name).returns(step_object)
        step_object.expects(:call).returns("result")

        @state_manager.expects(:save_state)
        @error_handler.expects(:with_error_handling).yields.returns("result")

        # Capture stderr output
        original_stderr = $stderr
        $stderr = StringIO.new

        @orchestrator.execute_step(step_name)

        output = $stderr.string
        assert_match(/Executing: test_step \(Resource type: unknown\)/, output)
      ensure
        $stderr = original_stderr
      end
    end
  end
end
