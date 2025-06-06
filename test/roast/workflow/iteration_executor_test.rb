# frozen_string_literal: true

require "test_helper"

class RoastWorkflowIterationExecutorTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @workflow.stubs(:output).returns({})
    @context_path = "/test/path"
    @state_manager = mock("state_manager")
    @executor = Roast::Workflow::IterationExecutor.new(@workflow, @context_path, @state_manager, {})
  end

  def test_execute_repeat_with_valid_config
    repeat_config = {
      "steps" => ["step1", "step2"],
      "until" => "counter > 5",
      "max_iterations" => 10,
    }

    repeat_step = mock("repeat_step")
    repeat_step.expects(:call).returns(["result1", "result2"])

    Roast::Workflow::RepeatStep.expects(:new).with(
      @workflow,
      steps: ["step1", "step2"],
      until_condition: "counter > 5",
      max_iterations: 10,
      name: "repeat_0",
      context_path: @context_path,
      config_hash: {},
    ).returns(repeat_step)

    @state_manager.expects(:save_state).with("repeat_counter___5", ["result1", "result2"])

    result = @executor.execute_repeat(repeat_config)

    assert_equal(["result1", "result2"], result)
    assert_equal(["result1", "result2"], @workflow.output["repeat_counter___5"])
  end

  def test_execute_repeat_missing_steps_raises_error
    repeat_config = {
      "until" => "counter > 5",
    }

    assert_raises(Roast::Workflow::WorkflowExecutor::ConfigurationError, "Missing 'steps' in repeat configuration") do
      @executor.execute_repeat(repeat_config)
    end
  end

  def test_execute_repeat_missing_until_raises_error
    repeat_config = {
      "steps" => ["step1"],
    }

    assert_raises(Roast::Workflow::WorkflowExecutor::ConfigurationError, "Missing 'until' condition in repeat configuration") do
      @executor.execute_repeat(repeat_config)
    end
  end

  def test_execute_each_with_valid_config
    each_config = {
      "each" => "items",
      "as" => "item",
      "steps" => ["process_item"],
    }

    each_step = mock("each_step")
    each_step.expects(:call).returns([{ item: 1, result: "processed1" }, { item: 2, result: "processed2" }])

    Roast::Workflow::EachStep.expects(:new).with(
      @workflow,
      collection_expr: "items",
      variable_name: "item",
      steps: ["process_item"],
      name: "each_item",
      context_path: @context_path,
      config_hash: {},
    ).returns(each_step)

    @state_manager.expects(:save_state).with("each_item", [{ item: 1, result: "processed1" }, { item: 2, result: "processed2" }])

    result = @executor.execute_each(each_config)

    assert_equal([{ item: 1, result: "processed1" }, { item: 2, result: "processed2" }], result)
    assert_equal([{ item: 1, result: "processed1" }, { item: 2, result: "processed2" }], @workflow.output["each_item"])
  end

  def test_execute_each_missing_collection_raises_error
    each_config = {
      "as" => "item",
      "steps" => ["process_item"],
    }

    assert_raises(Roast::Workflow::WorkflowExecutor::ConfigurationError, "Missing collection expression in each configuration") do
      @executor.execute_each(each_config)
    end
  end

  def test_execute_each_missing_as_raises_error
    each_config = {
      "each" => "items",
      "steps" => ["process_item"],
    }

    assert_raises(Roast::Workflow::WorkflowExecutor::ConfigurationError, "Missing 'as' variable name in each configuration") do
      @executor.execute_each(each_config)
    end
  end

  def test_execute_each_missing_steps_raises_error
    each_config = {
      "each" => "items",
      "as" => "item",
    }

    assert_raises(Roast::Workflow::WorkflowExecutor::ConfigurationError, "Missing 'steps' in each configuration") do
      @executor.execute_each(each_config)
    end
  end
end
