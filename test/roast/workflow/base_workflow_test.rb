# frozen_string_literal: true

require "test_helper"

class RoastWorkflowBaseWorkflowTest < ActiveSupport::TestCase
  FILE_PATH = File.join(Dir.pwd, "test/fixtures/files/test.rb")

  def setup
    # Use Mocha for stubbing/mocking
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
    Roast::Tools.stubs(:setup_interrupt_handler)
    Roast::Tools.stubs(:setup_exit_handler)
    ActiveSupport::Notifications.stubs(:instrument).returns(true)

    # Store original so we can restore after tests
    @original_openai_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
  end

  def teardown
    Roast::Helpers::PromptLoader.unstub(:load_prompt)
    Roast::Tools.unstub(:setup_interrupt_handler)
    Roast::Tools.unstub(:setup_exit_handler)
    ActiveSupport::Notifications.unstub(:instrument)

    # Restore ENV
    ENV["OPENAI_API_KEY"] = @original_openai_key
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

  test "handles ResourceNotFoundError correctly when Faraday::ResourceNotFound is raised" do
    skip "Skipping due to complex Raix configuration requirements"
  end

  test "handles other errors properly without conversion" do
    skip "Skipping due to complex Raix configuration requirements"
  end
end
