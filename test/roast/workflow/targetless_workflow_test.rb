# frozen_string_literal: true

require "test_helper"
require "mocha/minitest"
require "roast/workflow/configuration_parser"
require "roast/workflow/base_workflow"
require "roast/resources/none_resource"
require "roast/workflow/workflow_executor"

class RoastWorkflowTargetlessWorkflowTest < ActiveSupport::TestCase
  def setup
    @workflow_path = fixture_file_path("targetless_workflow.yml")
    mock_openai_client = mock
    OpenAI::Client.stubs(:new).with(access_token: "test_openai_token").returns(mock_openai_client)
    mock_openai_client.stubs(:models).returns(mock_openai_client)
    mock_openai_client.stubs(:list).returns([])
    @parser = Roast::Workflow::ConfigurationParser.new(@workflow_path)
  end

  class MockedExecution < RoastWorkflowTargetlessWorkflowTest
    def setup
      super
      # Stub setup_workflow and parse on the parser instance
      @workflow_double = mock("workflow")
      @workflow_double.stubs(:output).returns({})
      @parser.stubs(:setup_workflow).returns(@workflow_double)
      @parser.stubs(:parse)
    end

    def test_executes_workflow_without_a_target
      @parser.expects(:setup_workflow).with(nil, has_entries(name: instance_of(String), context_path: instance_of(String)))
      @parser.expects(:parse)
      @parser.begin!
    end
  end

  class RealBaseWorkflow < RoastWorkflowTargetlessWorkflowTest
    def setup
      super
      @workflow = mock("workflow")
      @workflow.stubs(:output).returns({})
      @workflow.stubs(:final_output).returns("")
      @workflow.stubs(:output_file).returns(nil)
      @workflow.stubs(:output_file=)
      @workflow.stubs(:verbose=)
      # Stub execute_steps to return the workflow
      Roast::Workflow::WorkflowExecutor.any_instance.stubs(:execute_steps).returns(@workflow)
    end

    def test_initializes_base_workflow_with_nil_file
      Roast::Workflow::BaseWorkflow.expects(:new).with do |file, options|
        assert_nil(file)
        assert_kind_of(String, options[:name])
        assert_kind_of(String, options[:context_path])
        assert_kind_of(Roast::Resources::NoneResource, options[:resource])
        true
      end.returns(@workflow)
      @parser.begin!
    end
  end
end
