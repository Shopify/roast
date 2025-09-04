# frozen_string_literal: true

require "test_helper"

class RoastWorkflowBaseStepTest < ActiveSupport::TestCase
  # Helper to load fixture files
  def fixture_file(filename)
    File.join(Dir.pwd, "test/fixtures/files", filename)
  end

  def setup
    @file = fixture_file("test.rb")
    @workflow = Roast::Workflow::BaseWorkflow.new(@file)
    @step = Roast::Workflow::BaseStep.new(@workflow)
  end

  test "initialize sets workflow and default model" do
    assert_equal @workflow, @step.workflow
    assert_equal Roast::Workflow::StepLoader::DEFAULT_MODEL, @step.model
  end

  test "initialize accepts custom model" do
    custom_model = "gpt-4"
    step_with_custom_model = Roast::Workflow::BaseStep.new(@workflow, model: custom_model)
    assert_equal custom_model, step_with_custom_model.model
  end

  test "call adds prompt to transcript and calls chat completion" do
    # Stub PromptLoader and chat_completion
    Roast::Helpers::PromptLoader.stubs(:load_prompt)
      .with(@step, @workflow.file)
      .returns("Test prompt")

    @workflow.stubs(:chat_completion)
      .returns("Test chat completion response")

    @workflow.stubs(:openai?)
      .returns(true)

    @workflow.stubs(:tools)
      .returns(nil)

    result = @step.call
    assert_equal({ user: "Test prompt" }, @workflow.transcript.last)
    assert_equal "Test chat completion response", result
  end

  test "available_tools attribute defaults to nil" do
    assert_nil @step.available_tools
  end

  test "available_tools can be set" do
    tools = ["grep", "read_file"]
    @step.available_tools = tools
    assert_equal tools, @step.available_tools
  end

  test "call with available_tools passes tools to chat_completion" do
    available_tools = ["grep", "search_file"]
    @step.available_tools = available_tools

    Roast::Helpers::PromptLoader.stubs(:load_prompt)
      .with(@step, @workflow.file)
      .returns("Test prompt")

    @workflow.stubs(:openai?)
      .returns(true)

    # Expect chat_completion to be called with available_tools parameter
    @workflow.expects(:chat_completion)
      .with(openai: @step.model, model: @step.model, json: false, params: {}, available_tools: available_tools)
      .returns("Test response")

    @step.call
  end

  test "call without available_tools passes nil tools" do
    Roast::Helpers::PromptLoader.stubs(:load_prompt)
      .with(@step, @workflow.file)
      .returns("Test prompt")

    @workflow.stubs(:openai?)
      .returns(true)

    # Expect chat_completion to be called with available_tools: nil
    @workflow.expects(:chat_completion)
      .with(openai: @step.model, model: @step.model, json: false, params: {}, available_tools: nil)
      .returns("Test response")

    @step.call
  end
end
