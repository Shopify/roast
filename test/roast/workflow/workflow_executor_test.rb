# frozen_string_literal: true

require "test_helper"
require "roast/workflow/workflow_executor"

class RoastWorkflowWorkflowExecutorTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @output = {}
    @workflow.stubs(output: @output)
    @config_hash = { "step1" => { "model" => "test-model" } }
    @context_path = "/tmp/test"
    @executor = Roast::Workflow::WorkflowExecutor.new(@workflow, @config_hash, @context_path)
  end

  # String steps tests
  test "executes string steps" do
    @executor.expects(:execute_step).with("step1")
    @executor.execute_steps(["step1"])
  end

  test "executes string steps with interpolation" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    @executor.expects(:execute_step).with("step test.rb")
    @executor.execute_steps(["step {{file}}"])
  end

  test "executes string steps with correct configuration" do
    @executor = Roast::Workflow::WorkflowExecutor.new(
      @workflow,
      # Use a non-default model to ensure we pass it through
      @config_hash.merge("model" => "gpt-4-mini"),
      @context_path,
    )

    @workflow.stubs(resource: nil, append_to_final_output: nil, openai?: true)
    @workflow.expects(:transcript).returns([])
    @workflow.stubs(:chat_completion).with(openai: "gpt-4-mini", model: "gpt-4-mini", loop: false, json: false, params: {})
      .returns("Test chat completion response")
    result = @executor.execute_step("execute step")
    assert_equal "Test chat completion response", result
  end

  # Hash steps tests
  test "executes hash steps" do
    @executor.expects(:execute_step).with("command1").returns("result")
    @executor.execute_steps([{ "var1" => "command1" }])
    assert_equal "result", @output["var1"]
  end

  test "executes hash steps with interpolation in key" do
    @workflow.expects(:instance_eval).with("var_name").returns("test_var")
    @executor.expects(:execute_step).with("command1").returns("result")
    @executor.execute_steps([{ "{{var_name}}" => "command1" }])
    assert_equal "result", @output["test_var"]
  end

  test "executes hash steps with interpolation in value" do
    @workflow.expects(:instance_eval).with("cmd").returns("test_command")
    @executor.expects(:execute_step).with("test_command").returns("result")
    @executor.execute_steps([{ "var1" => "{{cmd}}" }])
    assert_equal "result", @output["var1"]
  end

  test "executes hash steps with interpolation in both key and value" do
    @workflow.expects(:instance_eval).with("var_name").returns("test_var")
    @workflow.expects(:instance_eval).with("cmd").returns("test_command")
    @executor.expects(:execute_step).with("test_command").returns("result")
    @executor.execute_steps([{ "{{var_name}}" => "{{cmd}}" }])
    assert_equal "result", @output["test_var"]
  end

  # Array steps (parallel execution) tests
  test "executes steps in parallel" do
    mock_thread = mock
    mock_thread.expects(:join).twice
    Thread.expects(:new).twice.returns(mock_thread)

    @executor.execute_steps([["step1", "step2"]])
  end

  # Unknown step type tests
  test "raises an error for unknown step type" do
    assert_raises(RuntimeError) do
      @executor.execute_steps([Object.new])
    end
  end

  # Instrumentation tests
  test "instruments step execution" do
    events = []

    subscription = ActiveSupport::Notifications.subscribe(/roast\.step\./) do |name, _start, _finish, _id, payload|
      events << { name: name, payload: payload }
    end

    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.expects(:find_and_load_step).returns(step_obj)

    @executor.execute_step("test_step")

    start_event = events.find { |e| e[:name] == "roast.step.start" }
    complete_event = events.find { |e| e[:name] == "roast.step.complete" }

    refute_nil start_event
    assert_equal "test_step", start_event[:payload][:step_name]

    refute_nil complete_event
    assert_equal "test_step", complete_event[:payload][:step_name]
    assert complete_event[:payload][:success]
    assert_instance_of Float, complete_event[:payload][:execution_time]
    assert_instance_of Integer, complete_event[:payload][:result_size]

    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  test "instruments step errors" do
    events = []

    subscription = ActiveSupport::Notifications.subscribe(/roast\.step\./) do |name, _start, _finish, _id, payload|
      events << { name: name, payload: payload }
    end

    @executor.expects(:find_and_load_step).raises(StandardError.new("test error"))

    assert_raises(StandardError) do
      @executor.execute_step("failing_step")
    end

    error_event = events.find { |e| e[:name] == "roast.step.error" }

    refute_nil error_event
    assert_equal "failing_step", error_event[:payload][:step_name]
    assert_equal "StandardError", error_event[:payload][:error]
    assert_equal "test error", error_event[:payload][:message]
    assert_instance_of Float, error_event[:payload][:execution_time]

    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  # Bash expression tests
  test "executes shell command for bash expression" do
    @executor.expects(:strip_and_execute).with("$(ls)").returns("file1\nfile2")
    @workflow.expects(:transcript).returns([]).twice

    result = @executor.execute_step("$(ls)")
    assert_equal "file1\nfile2", result
  end

  # Glob pattern tests
  test "expands glob pattern" do
    @executor.expects(:glob).with("*.rb").returns("file1.rb\nfile2.rb")

    result = @executor.execute_step("*.rb")
    assert_equal "file1.rb\nfile2.rb", result
  end

  # Regular step tests
  test "loads and executes step object" do
    step_object = mock("step")
    step_object.expects(:call).returns("result")
    @executor.expects(:find_and_load_step).returns(step_object)
    @workflow.output.expects(:[]=).with("step1", "result")

    result = @executor.execute_step("step1")
    assert_equal "result", result
  end

  # Interpolation tests
  test "interpolates simple expressions in step names" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    result = @executor.interpolate("{{file}}")
    assert_equal "test.rb", result
  end

  test "interpolates expressions with surrounding text" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    result = @executor.interpolate("Process {{file}} with rubocop")
    assert_equal "Process test.rb with rubocop", result
  end

  test "interpolates expressions in shell commands" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    @executor.expects(:strip_and_execute).with("$(rubocop -A test.rb)").returns("Shell output")
    @workflow.expects(:transcript).returns([]).at_least(1)

    # First interpolate is called in execute_string_step (via execute_steps),
    # then the command is passed to execute_step and the result is finally strip_and_execute
    @executor.execute_steps(["$(rubocop -A {{file}})"])
  end

  test "leaves expressions unchanged when interpolation fails" do
    @workflow.expects(:instance_eval).with("unknown_var").raises(NameError.new("undefined local variable"))
    result = @executor.interpolate("Process {{unknown_var}}")
    assert_equal "Process {{unknown_var}}", result
  end

  test "interpolates multiple expressions" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    @workflow.expects(:instance_eval).with("line").returns("42")
    result = @executor.interpolate("{{file}}:{{line}}")
    assert_equal "test.rb:42", result
  end

  test "interpolates output from previous steps" do
    @output["previous_step"] = "previous result"
    @workflow.expects(:instance_eval).with("output['previous_step']").returns("previous result")
    result = @executor.interpolate("Using {{output['previous_step']}}")
    assert_equal "Using previous result", result
  end
end
