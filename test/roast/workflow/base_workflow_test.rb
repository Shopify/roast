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

  test "workflow has metadata manager" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    assert_respond_to workflow, :metadata
    assert_respond_to workflow, :metadata=
  end

  test "metadata returns DotAccessHash" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    assert_instance_of Roast::Workflow::DotAccessHash, workflow.metadata
  end

  test "can set and get metadata" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    workflow.metadata["step1"] = { "key" => "value" }

    assert_equal "value", workflow.metadata.step1.key
    assert_equal "value", workflow.metadata["step1"]["key"]
  end

  test "metadata is delegated to metadata manager" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    # Set metadata
    workflow.metadata = { "test" => "data" }

    # Should be reflected in the manager
    metadata_manager = workflow.instance_variable_get(:@metadata_manager)
    assert_equal({ "test" => "data" }, metadata_manager.to_h)
  end

  test "metadata persists through workflow lifecycle" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    # Add metadata during workflow execution
    workflow.metadata["initialization"] = { "timestamp" => "2024-01-15" }
    workflow.metadata["step1"] = { "duration" => 100 }
    workflow.metadata["step2"] = { "success" => true }

    # Verify all metadata is accessible
    assert_equal "2024-01-15", workflow.metadata.initialization.timestamp
    assert_equal 100, workflow.metadata.step1.duration
    assert_equal true, workflow.metadata.step2.success

    # Get full metadata snapshot
    all_metadata = workflow.metadata.to_h
    assert_equal 3, all_metadata.keys.size
    assert all_metadata.key?("initialization")
    assert all_metadata.key?("step1")
    assert all_metadata.key?("step2")
  end

  test "metadata and output are separate stores" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    # Set output
    workflow.output["step1"] = "User visible output"

    # Set metadata
    workflow.metadata["step1"] = { "internal" => "tracking data" }

    # Verify they are separate
    assert_equal "User visible output", workflow.output["step1"]
    assert_equal({ "internal" => "tracking data" }, workflow.metadata["step1"])

    # Changing one doesn't affect the other
    workflow.output["step1"] = "Updated output"
    assert_equal({ "internal" => "tracking data" }, workflow.metadata["step1"])

    workflow.metadata["step1"]["internal"] = "Updated metadata"
    assert_equal "Updated output", workflow.output["step1"]
  end

  test "metadata survives workflow state changes" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)

    # Set initial metadata
    workflow.metadata["pre_execution"] = { "setup" => "complete" }

    # Simulate workflow execution state changes
    workflow.output["step1"] = "output1"
    workflow.metadata["step1"] = { "executed" => true }

    workflow.append_to_final_output("Final result")
    workflow.metadata["post_execution"] = { "cleanup" => "done" }

    # All metadata should still be present
    assert_equal "complete", workflow.metadata.pre_execution.setup
    assert_equal true, workflow.metadata.step1.executed
    assert_equal "done", workflow.metadata.post_execution.cleanup
  end
end
