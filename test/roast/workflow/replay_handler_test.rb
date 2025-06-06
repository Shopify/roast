# frozen_string_literal: true

require "test_helper"

class RoastWorkflowReplayHandlerTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @state_repository = mock("state_repository")
    @handler = Roast::Workflow::ReplayHandler.new(@workflow, state_repository: @state_repository)
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
end
