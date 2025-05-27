# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_executors/parallel_step_executor"

module Roast
  module Workflow
    module StepExecutors
      class ParallelStepExecutorTest < Minitest::Test
        def setup
          @workflow = mock("workflow")
          @workflow_executor = mock("workflow_executor")
          @workflow_executor.stubs(:workflow).returns(@workflow)
          @workflow_executor.stubs(:config_hash).returns({})
          @executor = ParallelStepExecutor.new(@workflow_executor)
        end

        def test_executes_steps_in_parallel
          steps = ["step1", "step2", "step3"]

          # Expect each step to be executed
          @workflow_executor.expects(:execute_steps).with(["step1"])
          @workflow_executor.expects(:execute_steps).with(["step2"])
          @workflow_executor.expects(:execute_steps).with(["step3"])

          @executor.execute(steps)
        end

        def test_waits_for_all_threads_to_complete
          steps = ["slow_step", "fast_step"]

          @workflow_executor.expects(:execute_steps).with(["slow_step"]).once
          @workflow_executor.expects(:execute_steps).with(["fast_step"]).once

          @executor.execute(steps)

          # All mocks should have been satisfied, proving threads completed
        end
      end
    end
  end
end
