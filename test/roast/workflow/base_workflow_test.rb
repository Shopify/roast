# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_workflow"
require "mocha/minitest"

class RoastWorkflowBaseWorkflowTest < ActiveSupport::TestCase
  FILE_PATH = File.join(Dir.pwd, "test/fixtures/files/test.rb")

  def setup
    # Use Mocha for stubbing/mocking
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
    Roast::Tools.stubs(:setup_interrupt_handler)
  end

  def teardown
    Roast::Helpers::PromptLoader.unstub(:load_prompt)
    Roast::Tools.unstub(:setup_interrupt_handler)
  end

  test "initializes with file and sets up transcript" do
    Roast::Tools.expects(:setup_interrupt_handler)
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    assert_equal FILE_PATH, workflow.file
    assert_equal [{ system: "Test prompt" }], workflow.transcript
  end

  test "initializes with nil file for targetless workflows" do
    Roast::Tools.expects(:setup_interrupt_handler)
    workflow = Roast::Workflow::BaseWorkflow.new(nil)

    assert_nil workflow.file
    assert_equal [{ system: "Test prompt" }], workflow.transcript
  end

  test "appends to final output and returns it" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    workflow.append_to_final_output("Test output")
    assert_equal "Test output", workflow.final_output
  end
end
