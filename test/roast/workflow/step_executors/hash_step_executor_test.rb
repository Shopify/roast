# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_executors/hash_step_executor"
require "roast/workflow/workflow_executor"

module Roast
  module Workflow
    module StepExecutors
      class HashStepExecutorTest < Minitest::Test
        def setup
          @workflow = mock("workflow")
          @workflow.stubs(:output).returns({})
          @config_hash = {}
          @workflow_executor = mock("workflow_executor")
          @workflow_executor.stubs(:workflow).returns(@workflow)
          @workflow_executor.stubs(:config_hash).returns(@config_hash)
          @executor = HashStepExecutor.new(@workflow_executor)
        end

        def test_executes_simple_command_step
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:interpolate).with("echo test").returns("echo test")
          @workflow_executor.expects(:execute_step).with("echo test", exit_on_error: true).returns("test output")

          @executor.execute({ "test_step" => "echo test" })

          assert_equal("test output", @workflow.output["test_step"])
        end

        def test_executes_nested_hash_step
          nested_step = { "inner_step" => "echo inner" }
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:execute_steps).with([nested_step])

          @executor.execute({ "test_step" => nested_step })
        end

        def test_respects_exit_on_error_configuration
          @config_hash["test_step"] = { "exit_on_error" => false }
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:interpolate).with("$(exit 1)").returns("$(exit 1)")
          @workflow_executor.expects(:execute_step).with("$(exit 1)", exit_on_error: false).returns("error output")

          @executor.execute({ "test_step" => "$(exit 1)" })
        end
      end
    end
  end
end
