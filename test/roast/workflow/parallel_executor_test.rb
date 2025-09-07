# frozen_string_literal: true

require "test_helper"

class RoastWorkflowParallelExecutorTest < ActiveSupport::TestCase
  def setup
    @executor = mock("WorkflowExecutor")
  end

  def test_executes_steps_in_parallel
    steps = ["step1", "step2", "step3"]
    execution_order = []
    mutex = Mutex.new

    # Mock the executor to track execution order with thread safety
    @executor.stubs(:execute_steps).with(anything) do |step_array|
      sleep(0.01) # Small delay to ensure parallelism
      mutex.synchronize do
        execution_order << step_array.first
      end
    end

    result = Roast::Workflow::ParallelExecutor.execute(steps, @executor)

    assert_equal(:success, result)
    assert_equal(3, execution_order.size)
    assert_includes(execution_order, "step1")
    assert_includes(execution_order, "step2")
    assert_includes(execution_order, "step3")
  end

  def test_propagates_errors_from_threads
    steps = ["step1", "step2", "step3"]
    error = Roast::Error.new("Step 2 failed")

    # Set up expectations for each step
    @executor.expects(:execute_steps).with(["step1"])
    @executor.expects(:execute_steps).with(["step2"]).raises(error)
    @executor.expects(:execute_steps).with(["step3"]).at_most_once # May not be called if step2 fails first

    exception = assert_raises(Roast::Error) do
      Roast::Workflow::ParallelExecutor.execute(steps, @executor)
    end
    assert_equal("Step 2 failed", exception.message)
  end

  def test_waits_for_all_threads_to_complete
    steps = ["step1", "step2"]
    completion_flags = { "step1" => false, "step2" => false }

    @executor.stubs(:execute_steps).with(anything) do |step_array|
      step = step_array.first
      sleep(step == "step1" ? 0.02 : 0.01)
      completion_flags[step] = true
    end

    Roast::Workflow::ParallelExecutor.execute(steps, @executor)

    assert(completion_flags["step1"], "Step 1 should have completed")
    assert(completion_flags["step2"], "Step 2 should have completed")
  end

  def test_handles_empty_steps_array
    result = Roast::Workflow::ParallelExecutor.execute([], @executor)
    assert_equal(:success, result)
  end

  def test_handles_single_step
    @executor.expects(:execute_steps).with(["single_step"])

    result = Roast::Workflow::ParallelExecutor.execute(["single_step"], @executor)
    assert_equal(:success, result)
  end
end
