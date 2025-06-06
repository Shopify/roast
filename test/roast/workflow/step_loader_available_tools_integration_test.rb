# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_loader"
require "roast/workflow/base_workflow"

module Roast
  module Workflow
    class StepLoaderAvailableToolsIntegrationTest < ActiveSupport::TestCase
      def setup
        @context_path = File.expand_path("../../fixtures/steps", __dir__)
      end

      def test_available_tools_validation_with_grep_and_read_file
        # Create a workflow with mocked functions representing Grep and ReadFile
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          grep: -> {},
          read_file: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {
            "available_tools" => ["grep", "read_file"],
          },
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_equal(["grep", "read_file"], step.available_tools)
      end

      def test_available_tools_with_cmd_subcommands
        # Create a workflow with mocked functions representing Cmd subcommands
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          pwd: -> {},
          ls: -> {},
          echo: -> {},
          git: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {
            "available_tools" => ["pwd", "ls"],
          },
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_equal(["pwd", "ls"], step.available_tools)
      end

      def test_mixed_tools_grep_and_cmd
        # Create a workflow with mixed tool types
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          grep: -> {},
          pwd: -> {},
          ls: -> {},
          read_file: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {
            "available_tools" => ["grep", "pwd"],
          },
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_equal(["grep", "pwd"], step.available_tools)
      end

      def test_empty_available_tools
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          grep: -> {},
          pwd: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {
            "available_tools" => [],
          },
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_equal([], step.available_tools)
      end

      def test_nil_available_tools
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          grep: -> {},
          pwd: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {
            "available_tools" => nil,
          },
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_nil(step.available_tools)
      end

      def test_no_available_tools_key
        workflow = mock("workflow")
        workflow.stubs(:functions).returns({
          grep: -> {},
          pwd: -> {},
        })
        workflow.stubs(:output).returns({})
        workflow.stubs(:resource).returns(nil)

        workflow_config = {
          "test" => {},
        }

        step_loader = StepLoader.new(workflow, workflow_config, @context_path)
        step = step_loader.load("test")

        assert_nil(step.available_tools)
      end
    end
  end
end
