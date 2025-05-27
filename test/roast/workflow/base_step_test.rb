# frozen_string_literal: true

require "test_helper"
require "roast/workflow/base_step"
require "roast/workflow/base_workflow"
require "mocha/minitest"

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
    assert_equal "anthropic:claude-3-7-sonnet", @step.model
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

    result = @step.call
    assert_equal({ user: "Test prompt" }, @workflow.transcript.last)
    assert_equal "Test chat completion response", result
  end
end
