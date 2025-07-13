# frozen_string_literal: true

require "test_helper"

class RoastWorkflowReplayHandlerTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @workflow.stubs(:metadata).returns({})
    @state_repository = mock("state_repository")
    @handler = Roast::Workflow::ReplayHandler.new(@workflow, state_repository: @state_repository)

    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
    Roast::Tools.stubs(:setup_interrupt_handler)
    Roast::Tools.stubs(:setup_exit_handler)
    ActiveSupport::Notifications.stubs(:instrument).returns(true)
  end

  def teardown
    Roast::Helpers::PromptLoader.unstub(:load_prompt)
    Roast::Tools.unstub(:setup_interrupt_handler)
    Roast::Tools.unstub(:setup_exit_handler)
    ActiveSupport::Notifications.unstub(:instrument)
  end

  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end

  def test_process_replay_returns_original_steps_when_no_replay_option
    steps = ["step1", "step2", "step3"]
    result = @handler.process_replay(steps, nil)
    assert_equal(steps, result)
    refute(@handler.processed)
  end

  def test_process_replay_returns_original_steps_when_already_processed
    handler = Roast::Workflow::ReplayHandler.new(@workflow, state_repository: @state_repository)
    # Process once
    @state_repository.expects(:load_state_before_step).returns(false)
    handler.process_replay(["step1"], "step1")
    assert(handler.processed)

    # Second call should return original steps
    steps = ["step1", "step2", "step3"]
    result = handler.process_replay(steps, "step2")
    assert_equal(steps, result)
  end

  def test_process_replay_skips_to_specified_step
    steps = ["step1", "step2", "step3", "step4"]
    @state_repository.expects(:load_state_before_step).returns(false)

    result = @handler.process_replay(steps, "step3")
    assert_equal(["step3", "step4"], result)
    assert(@handler.processed)
  end

  def test_process_replay_handles_step_not_found
    steps = ["step1", "step2", "step3"]

    output = capture_stderr do
      result = @handler.process_replay(steps, "nonexistent")
      assert_equal(steps, result)
    end

    assert_match(/Step nonexistent not found in workflow/, output)
    assert(@handler.processed)
  end

  def test_process_replay_with_timestamp
    steps = ["step1", "step2", "step3"]
    timestamp = "20230101_000000_000"
    @workflow.expects(:session_timestamp=).with(timestamp)
    @state_repository.expects(:load_state_before_step).with(@workflow, "step2", timestamp: timestamp).returns(false)

    result = @handler.process_replay(steps, "#{timestamp}:step2")
    assert_equal(["step2", "step3"], result)
  end

  def test_process_replay_with_invalid_timestamp_format
    steps = ["step1", "step2"]

    assert_raises(ArgumentError) do
      @handler.process_replay(steps, "invalid_timestamp:step1")
    end
  end

  def test_load_state_and_restore_without_timestamp
    step_name = "step2"
    state_data = { output: { "step1" => "result1" } }
    @state_repository.expects(:load_state_before_step).with(@workflow, step_name).returns(state_data)
    @workflow.expects(:respond_to?).with(:output=).returns(true)
    @workflow.expects(:output=).with(state_data[:output])

    result = @handler.load_state_and_restore(step_name)
    assert_equal(state_data, result)
  end

  def test_load_state_and_restore_with_timestamp
    step_name = "step2"
    timestamp = "20230101_000000_000"
    state_data = { output: { "step1" => "result1" } }
    @state_repository.expects(:load_state_before_step).with(@workflow, step_name, timestamp: timestamp).returns(state_data)
    @workflow.expects(:respond_to?).with(:output=).returns(true)
    @workflow.expects(:output=).with(state_data[:output])

    result = @handler.load_state_and_restore(step_name, timestamp: timestamp)
    assert_equal(state_data, result)
  end

  def test_load_state_and_restore_when_state_not_found
    step_name = "step2"
    @state_repository.expects(:load_state_before_step).returns(false)

    output = capture_stderr do
      result = @handler.load_state_and_restore(step_name)
      refute(result)
    end

    assert_match(/Could not find suitable state data/, output)
  end

  def test_restore_workflow_state_restores_all_properties
    state_data = {
      output: { "step1" => "result1" },
      transcript: [{ "user" => "test" }],
      final_output: ["output line"],
    }

    # Test output restoration
    @workflow.expects(:respond_to?).with(:output=).returns(true)
    @workflow.expects(:output=).with(state_data[:output])

    # Test transcript restoration - now uses clear and append
    transcript_mock = mock("transcript")
    @workflow.expects(:respond_to?).with(:transcript).returns(true)
    @workflow.expects(:transcript).returns(transcript_mock).at_least_once
    transcript_mock.expects(:respond_to?).with(:clear).returns(true)
    transcript_mock.expects(:respond_to?).with(:<<).returns(true)
    transcript_mock.expects(:clear)
    transcript_mock.expects(:<<).with({ "user" => "test" })

    # Test final_output restoration
    @workflow.expects(:respond_to?).with(:final_output=).returns(true)
    @workflow.expects(:final_output=).with(state_data[:final_output])

    @handler.send(:restore_workflow_state, state_data)
  end

  def test_restore_workflow_state_handles_string_final_output
    state_data = {
      final_output: "single output line",
    }

    # Only final_output should be restored since others are not in state_data
    @workflow.expects(:respond_to?).with(:final_output=).returns(true)
    @workflow.expects(:final_output=).with(["single output line"])

    @handler.send(:restore_workflow_state, state_data)
  end

  def test_restore_workflow_state_uses_instance_variable_when_no_setter
    state_data = {
      final_output: ["output line"],
    }

    # Only final_output should be restored since others are not in state_data
    @workflow.expects(:respond_to?).with(:final_output=).returns(false)
    @workflow.expects(:instance_variable_defined?).with(:@final_output).returns(true)
    @workflow.expects(:instance_variable_set).with(:@final_output, state_data[:final_output])

    @handler.send(:restore_workflow_state, state_data)
  end

  def test_restore_transcript_using_clear_and_append
    state_data = {
      transcript: [{ "user" => "msg1" }, { "assistant" => "msg2" }],
    }

    transcript = mock("transcript")
    # Only transcript should be restored since others are not in state_data
    @workflow.expects(:respond_to?).with(:transcript).returns(true)
    @workflow.expects(:transcript).returns(transcript).at_least_once
    transcript.expects(:respond_to?).with(:clear).returns(true)
    transcript.expects(:respond_to?).with(:<<).returns(true)
    transcript.expects(:clear)
    transcript.expects(:<<).with({ "user" => "msg1" })
    transcript.expects(:<<).with({ "assistant" => "msg2" })

    @handler.send(:restore_workflow_state, state_data)
  end

  def test_restore_workflow_state_restores_metadata
    workflow = Roast::Workflow::BaseWorkflow.new(nil, name: "test_workflow")
    handler = Roast::Workflow::ReplayHandler.new(workflow, state_repository: @state_repository)

    # Set some initial metadata
    workflow.metadata["initial"] = { "data" => "value" }

    # Create saved state with metadata
    state_data = {
      metadata: {
        "step1" => { "duration_ms" => 100 },
        "step2" => { "retries" => 3 },
      },
    }

    # Restore the state
    handler.send(:restore_workflow_state, state_data)

    # Verify metadata was restored (replacing the initial metadata)
    assert_equal(state_data[:metadata], workflow.metadata.to_h)
    assert_equal(100, workflow.metadata.step1.duration_ms)
    assert_equal(3, workflow.metadata.step2.retries)
    # Initial metadata should be gone
    assert_nil(workflow.metadata.initial)
  end

  def test_restore_workflow_state_handles_missing_metadata
    workflow = Roast::Workflow::BaseWorkflow.new(nil, name: "test_workflow")
    handler = Roast::Workflow::ReplayHandler.new(workflow, state_repository: @state_repository)

    # Set some initial metadata
    workflow.metadata["existing"] = { "should" => "remain" }

    # Saved state without metadata key
    state_data = {
      output: { "step1" => "result1" },
    }

    # Restore the state (should only restore output, not touch metadata)
    handler.send(:restore_workflow_state, state_data)

    # Verify output was restored
    assert_equal("result1", workflow.output["step1"])

    # Verify metadata was not changed (no metadata in state_data)
    assert_equal({ "existing" => { "should" => "remain" } }, workflow.metadata.to_h)
  end

  def test_restore_workflow_state_replaces_all_metadata
    workflow = Roast::Workflow::BaseWorkflow.new(nil, name: "test_workflow")
    handler = Roast::Workflow::ReplayHandler.new(workflow, state_repository: @state_repository)

    # Set initial metadata
    workflow.metadata["initial_step"] = { "preserved" => true }
    workflow.metadata["another_step"] = { "also_preserved" => false }

    # Verify initial state
    assert_equal(true, workflow.metadata.initial_step.preserved)
    assert_equal(false, workflow.metadata.another_step.also_preserved)

    # Saved state with different metadata
    state_data = {
      metadata: {
        "step1" => { "from_save" => "value1" },
        "step2" => { "from_save" => "value2" },
      },
    }

    # Restore the state
    handler.send(:restore_workflow_state, state_data)

    # Should have metadata from saved state
    assert_equal(
      {
        "step1" => { "from_save" => "value1" },
        "step2" => { "from_save" => "value2" },
      },
      workflow.metadata.to_h,
    )

    # Initial metadata should be gone (full replacement)
    refute(workflow.metadata.to_h.key?("initial_step"))
    refute(workflow.metadata.to_h.key?("another_step"))

    # New metadata should be accessible via dot notation
    assert_equal("value1", workflow.metadata.step1.from_save)
    assert_equal("value2", workflow.metadata.step2.from_save)
  end
end
