# frozen_string_literal: true

require "test_helper"
require "mocha/minitest"
require "roast/workflow/configuration_parser"
require "active_support/notifications"

class RoastWorkflowConfigurationParserTest < ActiveSupport::TestCase
  def setup
    @workflow_path = fixture_file("workflow/workflow.yml")
    mock_openai_client = mock
    OpenAI::Client.stubs(:new).with(access_token: "test_openai_token").returns(mock_openai_client)
    mock_openai_client.stubs(:models).returns(mock_openai_client)
    mock_openai_client.stubs(:list).returns([])
    @parser = Roast::Workflow::ConfigurationParser.new(@workflow_path)
  end

  def teardown
    OpenAI::Client.unstub(:new) if OpenAI::Client.respond_to?(:unstub)
    OpenRouter::Client.unstub(:new) if OpenRouter::Client.respond_to?(:unstub)
  end

  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end

  def test_initialize_with_example_workflow
    assert_instance_of(Roast::Workflow::Configuration, @parser.configuration)
    assert_equal("run_coverage", @parser.configuration.steps.first)
  end

  def test_no_api_key_provided
    workflow_path = fixture_file("openrouter_no_api_token_workflow.yml")

    error = assert_raises(Roast::AuthenticationError) do
      Roast::Workflow::ConfigurationParser.new(workflow_path)
    end

    assert_equal("API authentication failed: No API token provided or token is invalid", error.message)
  end

  def test_begin_without_files_or_target_runs_targetless_workflow
    executor = mock("WorkflowExecutor")
    executor.stubs(:execute_steps)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)

    workflow = mock("BaseWorkflow")
    workflow.stubs(:output).returns({})
    workflow.stubs(:final_output).returns("")
    workflow.stubs(:output_file).returns(nil)
    Roast::Workflow::BaseWorkflow.stubs(:new).returns(workflow)
    workflow.stubs(:output_file=)
    workflow.stubs(:verbose=)

    output = capture_stderr { @parser.begin! }
    assert_match(/Running targetless workflow/, output)
  end

  def test_begin_with_instrumentation_instruments_workflow_events
    test_file = fixture_file("test.rb")
    parser = Roast::Workflow::ConfigurationParser.new(@workflow_path, [test_file])
    events = []
    subscription = ActiveSupport::Notifications.subscribe(/roast\./) do |name, _start, _finish, _id, payload|
      events << { name: name, payload: payload }
    end

    executor = mock("WorkflowExecutor")
    executor.stubs(:execute_steps)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)

    begin
      parser.begin!
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    start_event = events.find { |e| e[:name] == "roast.workflow.start" }
    complete_event = events.find { |e| e[:name] == "roast.workflow.complete" }

    assert_not_nil(start_event)
    assert_equal(@workflow_path, start_event[:payload][:workflow_path])

    assert_not_nil(complete_event)
    assert_equal(true, complete_event[:payload][:success])
    assert_kind_of(Float, complete_event[:payload][:execution_time])
  end

  def test_begin_with_files_initializes_workflow_for_each_file
    test_file = fixture_file("test.rb")
    parser = Roast::Workflow::ConfigurationParser.new(@workflow_path, [test_file])
    executor = mock("WorkflowExecutor")
    # Use expects instead of stubs for verification
    Roast::Workflow::WorkflowExecutor.expects(:new).returns(executor)
    executor.stubs(:execute_steps)

    output = capture_stderr { parser.begin! }
    assert_match(/Running workflow for file: #{Regexp.escape(test_file)}/, output)
  end

  # Private method tests (via send)
  def test_find_step_index_in_array_finds_index_of_simple_string_steps
    steps = ["step1", { "var1" => "step2" }, ["step3", "step4"]]
    assert_equal(0, @parser.send(:find_step_index_in_array, steps, "step1"))
  end

  def test_find_step_index_in_array_finds_index_of_hash_steps
    steps = ["step1", { "var1" => "step2" }, ["step3", "step4"]]
    assert_equal(1, @parser.send(:find_step_index_in_array, steps, "var1"))
  end

  def test_find_step_index_in_array_finds_index_within_parallel_steps
    steps = ["step1", { "var1" => "step2" }, ["step3", "step4"]]
    assert_equal(2, @parser.send(:find_step_index_in_array, steps, "step3"))
    assert_equal(2, @parser.send(:find_step_index_in_array, steps, "step4"))
  end

  def test_find_step_index_in_array_returns_nil_for_nonexistent_steps
    steps = ["step1", { "var1" => "step2" }, ["step3", "step4"]]
    assert_nil(@parser.send(:find_step_index_in_array, steps, "nonexistent"))
  end

  def test_load_state_and_update_steps_returns_steps_from_requested_index_when_state_loading_fails
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    state_repository = mock("FileStateRepository")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    state_repository.expects(:load_state_before_step).returns(false)

    result = @parser.send(:load_state_and_update_steps, steps, 2, "step3", nil)
    assert_equal(["step3", "step4"], result)
  end

  def test_load_state_and_update_steps_returns_steps_from_requested_index_when_state_loading_succeeds
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    state_repository = mock("FileStateRepository")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    state_repository.expects(:load_state_before_step).returns({ step_name: "step2" })

    result = @parser.send(:load_state_and_update_steps, steps, 2, "step3", nil)
    assert_equal(["step3", "step4"], result)
  end

  def test_load_state_and_update_steps_returns_steps_from_requested_index_when_loading_from_timestamp_fails
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    state_repository = mock("FileStateRepository")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    state_repository.expects(:load_state_before_step).returns(false)
    timestamp = "20230101_000000_000"

    result = @parser.send(:load_state_and_update_steps, steps, 1, "step2", timestamp)
    assert_equal(["step2", "step3", "step4"], result)
  end

  def test_parse_with_replay_option_starts_execution_from_specified_step_when_no_state_exists
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    workflow.stubs(:output_file).returns(nil)
    workflow.stubs(:final_output).returns("")
    state_repository = mock("FileStateRepository")
    executor = mock("WorkflowExecutor")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)
    executor.stubs(:execute_steps)
    @parser.stubs(:save_final_output)
    @parser.instance_variable_set(:@options, { replay: "step3" })
    state_repository.expects(:load_state_before_step).returns(false)

    executor.expects(:execute_steps).with(["step3", "step4"])
    @parser.send(:parse, steps)
  end

  def test_parse_with_replay_option_starts_execution_from_specified_step_when_state_exists
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    workflow.stubs(:output_file).returns(nil)
    workflow.stubs(:final_output).returns("")
    state_repository = mock("FileStateRepository")
    executor = mock("WorkflowExecutor")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)
    executor.stubs(:execute_steps)
    @parser.stubs(:save_final_output)
    @parser.instance_variable_set(:@options, { replay: "step2" })
    state_repository.expects(:load_state_before_step).returns({ step_name: "step1" })

    executor.expects(:execute_steps).with(["step2", "step3", "step4"])
    @parser.send(:parse, steps)
  end

  def test_parse_with_replay_option_handles_timestamp_in_replay_parameter
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    workflow.stubs(:output_file).returns(nil)
    workflow.stubs(:final_output).returns("")
    workflow.stubs(:session_timestamp=)
    state_repository = mock("FileStateRepository")
    executor = mock("WorkflowExecutor")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)
    executor.stubs(:execute_steps)
    @parser.stubs(:save_final_output)
    timestamp = "20230101_000000_000"
    @parser.instance_variable_set(:@options, { replay: "#{timestamp}:step3" })
    state_repository.expects(:load_state_before_step).returns(false)

    workflow.expects(:session_timestamp=).with(timestamp)
    executor.expects(:execute_steps).with(["step3", "step4"])
    @parser.send(:parse, steps)
  end

  def test_parse_with_replay_option_runs_all_steps_when_specified_step_not_found
    steps = ["step1", "step2", "step3", "step4"]
    workflow = mock("BaseWorkflow")
    workflow.stubs(:output_file).returns(nil)
    workflow.stubs(:final_output).returns("")
    state_repository = mock("FileStateRepository")
    executor = mock("WorkflowExecutor")
    @parser.stubs(:current_workflow).returns(workflow)
    Roast::Workflow::FileStateRepository.stubs(:new).returns(state_repository)
    Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)
    executor.stubs(:execute_steps)
    @parser.stubs(:save_final_output)
    @parser.instance_variable_set(:@options, { replay: "nonexistent_step" })

    executor.expects(:execute_steps).with(steps)
    output = capture_stderr { @parser.send(:parse, steps) }
    assert_match(/Step nonexistent_step not found/, output)
  end

  def test_restore_workflow_state_properly_restores_workflow_properties
    # Create a simplified workflow class for testing
    test_workflow = Class.new(Object) do
      attr_accessor :output, :transcript, :final_output

      def initialize
        @output = {}
        @transcript = []
        @final_output = []
      end

      def instance_variable_defined?(name)
        true
      end
    end.new

    # Set up state data to restore
    state_data = {
      output: { "step1" => "result1", "step2" => "result2" },
      transcript: [{ "user" => "test message" }, { "assistant" => "test response" }],
      final_output: ["output line 1", "output line 2"],
    }

    # Set up parser with the test workflow
    @parser.stubs(:current_workflow).returns(test_workflow)

    # Call the method being tested
    @parser.send(:restore_workflow_state, state_data)

    # Verify the behavior by checking the end state
    assert_equal(state_data[:output], test_workflow.output)
    assert_equal(state_data[:transcript], test_workflow.transcript)
    assert_equal(state_data[:final_output], test_workflow.final_output)
  end
end
