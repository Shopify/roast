# frozen_string_literal: true

require "test_helper"

class RoastWorkflowTargetlessWorkflowTest < ActiveSupport::TestCase
  def setup
    # Create a simple targetless workflow for testing
    @tmpdir = Dir.mktmpdir
    @workflow_path = File.join(@tmpdir, "targetless_workflow.yml")
    File.write(@workflow_path, <<~YAML)
      name: Simple Targetless
      tools: []
      steps:
        - step1: $(echo "Hello from targetless workflow")
    YAML

    @original_openai_key = ENV.delete("OPENAI_API_KEY")

    # Stub the WorkflowInitializer to prevent API client validation
    Roast::Workflow::WorkflowInitializer.any_instance.stubs(:configure_api_client)

    @parser = Roast::Workflow::ConfigurationParser.new(@workflow_path)
  end

  def teardown
    Roast::Workflow::WorkflowInitializer.any_instance.unstub(:configure_api_client)
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    ENV["OPENAI_API_KEY"] = @original_openai_key
  end

  class MockedExecution < RoastWorkflowTargetlessWorkflowTest
    def test_executes_workflow_without_a_target
      # The workflow should execute with nil file for targetless workflows
      executor = mock("executor")
      executor.expects(:execute_steps)
      Roast::Workflow::WorkflowExecutor.stubs(:new).returns(executor)

      workflow = mock("workflow")
      workflow.stubs(:output_file).returns(nil)
      workflow.stubs(:final_output).returns("")
      workflow.stubs(:session_name).returns("targetless")
      workflow.stubs(:file).returns(nil)
      workflow.stubs(:session_timestamp).returns(nil)
      workflow.stubs(:respond_to?).with(:session_name).returns(true)
      workflow.stubs(:respond_to?).with(:final_output).returns(true)
      workflow.stubs(:storage_type=).with(nil)
      workflow.stubs(:model=)
      workflow.stubs(:context_management_config=)

      # Stub output_manager for the pre/post processing code
      output_manager = mock("output_manager")
      workflow.stubs(:output_manager).returns(output_manager)

      Roast::Workflow::BaseWorkflow.expects(:new).with(
        nil,
        has_entries(name: instance_of(String), context_path: instance_of(String)),
      ).returns(workflow)

      capture_io { @parser.begin! }
    end
  end

  def test_executes_workflow_without_a_target
    # The workflow should execute with nil file for targetless workflows
    output = capture_io { @parser.begin! }
    assert_match(/Running targetless workflow/, output.join)
  end

  def test_initializes_base_workflow_with_nil_file
    # Create a temporary targetless workflow file
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "targetless_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: Targetless Test
        steps:
          - step1: $(echo "Test step")
      YAML

      parser = Roast::Workflow::ConfigurationParser.new(workflow_file)
      configuration = parser.configuration

      # Verify configuration properties
      assert_nil(configuration.target)
      assert_equal("Targetless Test", configuration.name)
      assert_kind_of(Roast::Resources::NoneResource, configuration.resource)
    end
  end
end
