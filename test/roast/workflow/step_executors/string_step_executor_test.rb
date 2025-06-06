# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    module StepExecutors
      class StringStepExecutorTest < ActiveSupport::TestCase
        def setup
          @workflow = mock("workflow")
          @config_hash = {}
          @workflow_executor = mock("workflow_executor")
          @workflow_executor.stubs(:workflow).returns(@workflow)
          @workflow_executor.stubs(:config_hash).returns(@config_hash)
          @executor = StringStepExecutor.new(@workflow_executor)
        end

        def test_executes_direct_command_step
          @workflow_executor.expects(:interpolate).with("$(echo test)").returns("$(echo test)")
          @workflow_executor.expects(:execute_step).with("$(echo test)")

          @executor.execute("$(echo test)")
        end

        def test_executes_named_step_with_default_exit_on_error
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:execute_step).with("test_step", exit_on_error: true)

          @executor.execute("test_step")
        end

        def test_executes_named_step_with_configured_exit_on_error
          @config_hash["test_step"] = { "exit_on_error" => false }
          @workflow_executor.expects(:interpolate).with("test_step").returns("test_step")
          @workflow_executor.expects(:execute_step).with("test_step", exit_on_error: false)

          @executor.execute("test_step")
        end

        def test_interpolates_expressions_in_step
          @workflow_executor.expects(:interpolate).with("process_{{file}}").returns("process_test.rb")
          @workflow_executor.expects(:execute_step).with("process_test.rb", exit_on_error: true)

          @executor.execute("process_{{file}}")
        end
      end
    end
  end
end
