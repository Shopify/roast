# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ExitOnErrorIntegrationTest < ActiveSupport::TestCase
      include FixtureHelpers

      def setup
        @workflow = BaseWorkflow.new(nil, name: "test_workflow", workflow_configuration: mock_workflow_config)
        @workflow.output = {}
        @context_path = File.expand_path("../../fixtures/steps", __dir__)
        @config_hash = {}
      end

      def test_command_fails_by_default
        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        assert_raises(CommandExecutor::CommandExecutionError) do
          executor.execute_step("$(exit 1)")
        end
      end

      def test_command_continues_with_exit_on_error_false
        @config_hash = {
          "failing_command" => {
            "exit_on_error" => false,
          },
        }

        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        # Execute a hash step with a failing command
        step = { "failing_command" => "$(exit 42)" }
        executor.execute_steps([step])

        # Should not raise and should capture output with exit status
        assert(@workflow.output["failing_command"])
        assert_match(/\[Exit status: 42\]/, @workflow.output["failing_command"])
      end

      def test_command_output_includes_stdout_and_exit_status
        @config_hash = {
          "test_command" => {
            "exit_on_error" => false,
          },
        }

        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        # Execute a command that outputs text and fails
        step = { "test_command" => "$(echo 'Error: Something went wrong' && exit 1)" }
        executor.execute_steps([step])

        output = @workflow.output["test_command"]
        assert_match(/Error: Something went wrong/, output)
        assert_match(/\[Exit status: 1\]/, output)
      end

      def test_command_succeeds_regardless_of_exit_on_error
        @config_hash = {
          "good_command" => {
            "exit_on_error" => false,
          },
        }

        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        # Execute a successful command
        step = { "good_command" => "$(echo 'Success')" }
        executor.execute_steps([step])

        # Should capture output normally without exit status
        assert_equal("Success\n", @workflow.output["good_command"])
        refute_match(/\[Exit status:/, @workflow.output["good_command"])
      end

      def test_direct_command_step_always_exits_on_error
        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        # Direct command steps (without names) should always exit on error
        assert_raises(CommandExecutor::CommandExecutionError) do
          executor.execute_steps(["$(exit 1)"])
        end
      end

      def test_warning_logged_when_continuing_after_error
        @config_hash = {
          "warning_test" => {
            "exit_on_error" => false,
          },
        }

        executor = WorkflowExecutor.new(@workflow, @config_hash, @context_path)

        # Execute the step - warning will be logged to stderr via logger
        step = { "warning_test" => "$(exit 3)" }
        executor.execute_steps([step])

        # Verify the command executed and captured output with exit status
        assert(@workflow.output["warning_test"])
        assert_match(/\[Exit status: 3\]/, @workflow.output["warning_test"])
      end
    end
  end
end
