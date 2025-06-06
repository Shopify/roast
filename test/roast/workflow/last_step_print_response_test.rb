# frozen_string_literal: true

require "test_helper"

class RoastWorkflowLastStepPrintResponseTest < ActiveSupport::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  test "last step has print_response set to true by default" do
    workflow_content = <<~YAML
      name: test_workflow
      steps:
        - step1
        - step2
        - step3
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    config = Roast::Workflow::Configuration.new(workflow_path)

    # First two steps should not have print_response set
    assert_nil config.config_hash["step1"]
    assert_nil config.config_hash["step2"]

    # Last step should have print_response = true
    assert_equal true, config.config_hash["step3"]["print_response"]
  end

  test "last step respects explicit print_response configuration" do
    workflow_content = <<~YAML
      name: test_workflow
      steps:
        - step1
        - step2
        - step3
      step3:
        print_response: false
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    config = Roast::Workflow::Configuration.new(workflow_path)

    # Last step should keep its explicit configuration
    assert_equal false, config.config_hash["step3"]["print_response"]
  end

  test "last step with hash format has print_response set to true" do
    workflow_content = <<~YAML
      name: test_workflow
      steps:
        - step1
        - result: calculate_total
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    config = Roast::Workflow::Configuration.new(workflow_path)

    # Last step (with variable assignment) should have print_response = true
    assert_equal true, config.config_hash["result"]["print_response"]
  end

  test "parallel steps do not have print_response set" do
    workflow_content = <<~YAML
      name: test_workflow
      steps:
        - step1
        - [parallel1, parallel2]
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    config = Roast::Workflow::Configuration.new(workflow_path)

    # Parallel steps should not have print_response set
    assert_nil config.config_hash["parallel1"]
    assert_nil config.config_hash["parallel2"]
  end

  test "conditional last step has inner last step with print_response" do
    workflow_content = <<~YAML
      name: test_workflow
      steps:
        - step1
        - if: some_condition
          then:
            - inner_step1
            - inner_step2
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    config = Roast::Workflow::Configuration.new(workflow_path)

    # The last step inside the conditional should have print_response = true
    assert_equal true, config.config_hash["inner_step2"]["print_response"]
  end

  test "empty workflow does not error" do
    workflow_content = <<~YAML
      name: test_workflow
      steps: []
    YAML

    workflow_path = File.join(@tmpdir, "workflow.yml")
    File.write(workflow_path, workflow_content)

    # Should not raise an error
    assert_nothing_raised do
      Roast::Workflow::Configuration.new(workflow_path)
    end
  end
end
