# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_workflow"
require "mocha/minitest"

class RoastWorkflowBaseWorkflowTest < ActiveSupport::TestCase
  FILE_PATH = File.join(Dir.pwd, "test/fixtures/files/test.rb")

  def setup
    # Use Mocha for stubbing/mocking
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
    Roast::Tools.stubs(:setup_interrupt_handler)
  end

  def teardown
    Roast::Helpers::PromptLoader.unstub(:load_prompt)
    Roast::Tools.unstub(:setup_interrupt_handler)
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

  test "tool_supports_max_tokens? returns true for known tools" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    
    assert workflow.send(:tool_supports_max_tokens?, "read_file")
    assert workflow.send(:tool_supports_max_tokens?, "grep")
    refute workflow.send(:tool_supports_max_tokens?, "unknown_tool")
  end

  test "tool_supports_max_tokens? detects tools with max_tokens in schema" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    
    # Mock a tool schema that already has max_tokens parameter
    tool_schema = {
      name: "custom_tool",
      parameters: {
        properties: {
          max_tokens: { type: "integer", description: "Maximum tokens" },
          other_param: { type: "string" }
        }
      }
    }
    
    # Stub the super method to simulate a tool with max_tokens parameter
    workflow.class.any_instance.stubs(:function_schemas).returns([tool_schema])
    
    assert workflow.send(:tool_supports_max_tokens?, "custom_tool")
  end

  test "add_max_tokens_to_schema adds parameter when not present" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    
    original_schema = {
      name: "test_tool",
      parameters: {
        properties: {
          path: { type: "string" }
        }
      }
    }
    
    result = workflow.send(:add_max_tokens_to_schema, original_schema, 1000)
    
    assert result[:parameters][:properties][:max_tokens]
    assert_equal 1000, result[:parameters][:properties][:max_tokens][:default]
    assert_equal "integer", result[:parameters][:properties][:max_tokens][:type]
    
    # Original schema should be unchanged
    refute original_schema[:parameters][:properties][:max_tokens]
  end

  test "add_max_tokens_to_schema skips when max_tokens already exists" do
    workflow = Roast::Workflow::BaseWorkflow.new(FILE_PATH)
    
    original_schema = {
      name: "test_tool",
      parameters: {
        properties: {
          path: { type: "string" },
          max_tokens: { type: "integer", description: "Existing max_tokens" }
        }
      }
    }
    
    result = workflow.send(:add_max_tokens_to_schema, original_schema, 1000)
    
    # Should keep original max_tokens parameter unchanged
    assert_equal "Existing max_tokens", result[:parameters][:properties][:max_tokens][:description]
    refute_equal 1000, result[:parameters][:properties][:max_tokens][:default]
  end
end
