# frozen_string_literal: true

require "test_helper"

module Roast
  class WorkflowDiagramGeneratorTest < ActiveSupport::TestCase
    test "generates diagram for simple workflow" do
      workflow_path = fixture_file("valid_workflow.yml")
      workflow = Workflow::Configuration.new(workflow_path)
      generator = WorkflowDiagramGenerator.new(workflow, workflow_path)

      output_path = generator.generate

      assert File.exist?(output_path)
      assert_equal File.join(File.dirname(workflow_path), "valid_workflow.png"), output_path

      # Cleanup
      File.delete(output_path) if File.exist?(output_path)
    end

    test "handles inline prompts" do
      workflow_yaml = {
        "name" => "Test workflow",
        "tools" => ["bash"],
        "steps" => ["step1", "prompt: This is an inline prompt", "step2"],
      }

      Dir.mktmpdir do |tmpdir|
        workflow_file = File.join(tmpdir, "test_workflow.yml")
        File.write(workflow_file, workflow_yaml.to_yaml)

        workflow = Workflow::Configuration.new(workflow_file)
        generator = WorkflowDiagramGenerator.new(workflow, workflow_file)

        output_path = generator.generate
        assert File.exist?(output_path)
        assert_equal File.join(tmpdir, "test_workflow.png"), output_path
        File.delete(output_path)
      end
    end

    test "handles control flow structures" do
      workflow_yaml = {
        "name" => "Control flow test",
        "tools" => ["bash"],
        "steps" => [
          { "if" => "condition", "then" => ["step1"], "else" => ["step2"] },
          { "each" => "items", "do" => ["process_item"] },
          { "repeat" => 3, "do" => ["repeated_step"] },
        ],
      }

      Dir.mktmpdir do |tmpdir|
        workflow_file = File.join(tmpdir, "control_flow_workflow.yml")
        File.write(workflow_file, workflow_yaml.to_yaml)

        workflow = Workflow::Configuration.new(workflow_file)
        generator = WorkflowDiagramGenerator.new(workflow, workflow_file)

        output_path = generator.generate
        assert File.exist?(output_path)
        assert_equal File.join(tmpdir, "control_flow_workflow.png"), output_path
        File.delete(output_path)
      end
    end

    test "initializes with workflow configuration" do
      workflow_path = fixture_file("valid_workflow.yml")
      workflow = Workflow::Configuration.new(workflow_path)

      generator = WorkflowDiagramGenerator.new(workflow, workflow_path)

      assert_not_nil generator
    end

    test "generates correct output filename from workflow path" do
      workflow = mock("workflow")
      workflow.stubs(:metadata).returns({})
      workflow.stubs(:name).returns("Test Workflow")
      workflow.stubs(:steps).returns([])

      generator = WorkflowDiagramGenerator.new(workflow, "/path/to/my_workflow.yml")
      expected_path = "/path/to/my_workflow.png"

      # Use send to access private method
      actual_path = generator.send(:generate_output_filename)

      assert_equal expected_path, actual_path
    end

    test "generates fallback filename when no path provided" do
      workflow = mock("workflow")
      workflow.stubs(:metadata).returns({})
      workflow.stubs(:name).returns("Test Workflow!")
      workflow.stubs(:steps).returns([])

      generator = WorkflowDiagramGenerator.new(workflow)

      # Use send to access private method
      actual_path = generator.send(:generate_output_filename)

      assert_equal "test_workflow_diagram.png", actual_path
    end
  end
end
