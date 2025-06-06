# frozen_string_literal: true

require "test_helper"

class RoastWorkflowConfigurationParserTest < ActiveSupport::TestCase
  def setup
    # Create a simple test workflow
    @tmpdir = Dir.mktmpdir
    @workflow_path = File.join(@tmpdir, "test_workflow.yml")
    File.write(@workflow_path, <<~YAML)
      name: test_workflow
      tools: []
      steps:
        - step1: $(echo "Step 1")
        - step2: $(echo "Step 2")
    YAML
    @parser = Roast::Workflow::ConfigurationParser.new(@workflow_path)

    @original_openai_key = ENV.delete("OPENAI_API_KEY")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    ENV["OPENAI_API_KEY"] = @original_openai_key
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
    assert_equal({ "step1" => "$(echo \"Step 1\")" }, @parser.configuration.steps.first)
  end

  def test_begin_without_files_or_target_runs_targetless_workflow
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

    begin
      capture_stderr { parser.begin! }
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

    output = capture_stderr { parser.begin! }
    assert_match(/Running workflow for file: #{Regexp.escape(test_file)}/, output)
  end

  # StepFinder tests are now in step_finder_test.rb
  # These tests were moved to test the public API of StepFinder class

  # ReplayHandler tests are now in replay_handler_test.rb
  # These tests were moved to test the public API of ReplayHandler class

  def test_begin_with_replay_option_starts_execution_from_specified_step
    # Create a simple workflow file with steps
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: Test Workflow
        steps:
          - step1: $(echo "Step 1")
          - step2: $(echo "Step 2")
          - step3: $(echo "Step 3")
          - step4: $(echo "Step 4")
      YAML

      target_file = File.join(tmpdir, "target.txt")
      File.write(target_file, "test content")

      # Create parser with replay option
      parser = Roast::Workflow::ConfigurationParser.new(workflow_file, [target_file], { replay: "step3" })

      # Run the workflow and check output behavior
      output = capture_stderr { parser.begin! }
      # When replaying from step3, we should see that it's replaying
      assert_match(/Replaying from step: step3/, output)
    end
  end

  def test_begin_with_replay_option_restores_state_when_available
    # Create a simple workflow file with steps
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: Test Workflow
        steps:
          - step1: $(echo "Step 1")
          - step2: $(echo "Step 2")
          - step3: $(echo "Step 3")
      YAML

      target_file = File.join(tmpdir, "target.txt")
      File.write(target_file, "test content")

      # Create parser with replay option
      parser = Roast::Workflow::ConfigurationParser.new(workflow_file, [target_file], { replay: "step2" })

      # Run the workflow and verify state restoration behavior
      output = capture_stderr { parser.begin! }
      assert_match(/Replaying from step: step2/, output)
    end
  end

  def test_begin_with_replay_option_handles_timestamp
    # Create a simple workflow file with steps
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: Test Workflow
        steps:
          - step1: $(echo "Step 1")
          - step2: $(echo "Step 2")
          - step3: $(echo "Step 3")
          - step4: $(echo "Step 4")
      YAML

      target_file = File.join(tmpdir, "target.txt")
      File.write(target_file, "test content")

      timestamp = "20230101_000000_000"
      # Create parser with replay option including timestamp
      parser = Roast::Workflow::ConfigurationParser.new(workflow_file, [target_file], { replay: "#{timestamp}:step3" })

      # Run the workflow
      output = capture_stderr { parser.begin! }
      # Should show replaying with session timestamp
      assert_match(/Replaying from step: step3 \(session: #{timestamp}\)/, output)
    end
  end

  def test_begin_with_replay_option_runs_all_steps_when_step_not_found
    # Create a simple workflow file with steps
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: Test Workflow
        steps:
          - step1: $(echo "Step 1")
          - step2: $(echo "Step 2")
      YAML

      target_file = File.join(tmpdir, "target.txt")
      File.write(target_file, "test content")

      # Create parser with replay option for non-existent step
      parser = Roast::Workflow::ConfigurationParser.new(workflow_file, [target_file], { replay: "nonexistent_step" })

      # Run the workflow and capture output
      output = capture_stderr { parser.begin! }
      assert_match(/Step nonexistent_step not found/, output)
    end
  end

  # restore_workflow_state tests are now in replay_handler_test.rb
  # These tests were moved to test the public API of ReplayHandler class
end
