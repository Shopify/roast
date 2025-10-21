# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    module StepExecutors
      class HashStepExecutorTest < ActiveSupport::TestCase
        def setup
          @workflow = mock("workflow")
          @workflow.stubs(:output).returns({})
          @workflow.stubs(:metadata).returns({})
          @config_hash = {}
          @coordinator = mock("coordinator")
          @workflow_executor = mock("workflow_executor")
          @workflow_executor.stubs(:workflow).returns(@workflow)
          @workflow_executor.stubs(:config_hash).returns(@config_hash)
          @workflow_executor.stubs(:step_executor_coordinator).returns(@coordinator)
          @executor = HashStepExecutor.new(@workflow_executor)
        end

        def test_executes_simple_command_step
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:interpolate).with("echo test").returns("echo test")
          @coordinator.expects(:execute_step).with("echo test", exit_on_error: true, step_key: "test_step").returns("test output")

          @executor.execute({ "test_step" => "echo test" })

          assert_equal("test output", @workflow.output["test_step"])
        end

        def test_executes_nested_hash_step
          nested_step = { "inner_step" => "echo inner" }
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @coordinator.expects(:execute_steps).with([nested_step])

          @executor.execute({ "test_step" => nested_step })
        end

        def test_respects_exit_on_error_configuration
          @config_hash["test_step"] = { "exit_on_error" => false }
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:interpolate).with("$(exit 1)").returns("$(exit 1)")
          @coordinator.expects(:execute_step).with("$(exit 1)", exit_on_error: false, step_key: "test_step").returns("error output")

          @executor.execute({ "test_step" => "$(exit 1)" })
        end
      end
    end
  end
end
