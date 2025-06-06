# frozen_string_literal: true

require "test_helper"

class RoastWorkflowRunnerTest < ActiveSupport::TestCase
  def setup
    # Create a real configuration with a temporary workflow file
    @tmpdir = Dir.mktmpdir
    @workflow_file = File.join(@tmpdir, "test_workflow.yml")
    File.write(@workflow_file, <<~YAML)
      name: test_workflow
      tools: []
      steps:
        - step1: $(echo "Step 1")
        - step2: $(echo "Step 2")
    YAML

    @configuration = Roast::Workflow::Configuration.new(@workflow_file)
    @options = { output: "/tmp/output.txt", verbose: true }
    @runner = Roast::Workflow::WorkflowRunner.new(@configuration, @options)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  def test_run_for_files_processes_each_file
    # Create test files
    file1 = File.join(@tmpdir, "file1.rb")
    file2 = File.join(@tmpdir, "file2.rb")
    File.write(file1, "# File 1")
    File.write(file2, "# File 2")
    files = [file1, file2]

    # Run and verify output
    assert_output(nil, /Running workflow for file: #{Regexp.escape(file1)}.*Running workflow for file: #{Regexp.escape(file2)}.*ROAST COMPLETE!/m) do
      @runner.run_for_files(files)
    end
  end

  def test_run_for_files_warns_when_target_present
    # Create a workflow with a target
    File.write(@workflow_file, <<~YAML)
      name: test_workflow
      target: "ignored_target.rb"
      tools: []
      steps:
        - step1: $(echo "Step 1")
    YAML

    configuration_with_target = Roast::Workflow::Configuration.new(@workflow_file)
    runner = Roast::Workflow::WorkflowRunner.new(configuration_with_target, @options)

    file1 = File.join(@tmpdir, "file1.rb")
    File.write(file1, "# File 1")
    files = [file1]

    assert_output(nil, /WARNING: Ignoring target parameter.*ignored_target\.rb/) do
      runner.run_for_files(files)
    end
  end

  def test_run_for_targets_processes_each_target_line
    # Create target files
    target1 = File.join(@tmpdir, "target1.rb")
    target2 = File.join(@tmpdir, "target2.rb")
    File.write(target1, "# Target 1")
    File.write(target2, "# Target 2")

    # Create workflow with targets
    File.write(@workflow_file, <<~YAML)
      name: test_workflow
      target: "#{target1}\n#{target2}"
      tools: []
      steps:
        - step1: $(echo "Step 1")
    YAML

    configuration_with_targets = Roast::Workflow::Configuration.new(@workflow_file)
    runner = Roast::Workflow::WorkflowRunner.new(configuration_with_targets, @options)

    output = capture_io { runner.run_for_targets }
    # The target appears as a single line with both files
    assert_match(/Running workflow for file:/, output.join)
    assert_match(/ROAST COMPLETE!/, output.join)
  end

  def test_run_targetless_creates_workflow_with_nil_file
    assert_output(nil, /Running targetless workflow.*ROAST COMPLETE!/m) do
      @runner.run_targetless
    end
  end

  def test_handles_replay_option
    # Test replay option behavior
    File.write(@workflow_file, <<~YAML)
      name: test_workflow
      tools: []
      steps:
        - step1: $(echo "Step 1")
        - step2: $(echo "Step 2")
    YAML

    configuration = Roast::Workflow::Configuration.new(@workflow_file)
    runner = Roast::Workflow::WorkflowRunner.new(configuration, { replay: "step2" })

    output = capture_io { runner.run_targetless }
    # Check for replay behavior in output
    assert_match(/Replaying from step: step2/, output.join)
  end
end
