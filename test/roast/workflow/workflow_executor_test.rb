# frozen_string_literal: true

require "test_helper"
require "roast/workflow/workflow_executor"
require "tmpdir"

class RoastWorkflowWorkflowExecutorTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @output = {}
    @workflow.stubs(output: @output, pause_step_name: nil, verbose: false)
    @config_hash = { "step1" => { "model" => "test-model" } }
    @context_path = "/tmp/test"
    @executor = Roast::Workflow::WorkflowExecutor.new(@workflow, @config_hash, @context_path)
  end

  # String steps tests
  test "executes string steps" do
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("step1", step_key: "step1").returns(step_obj)
    @executor.execute_steps(["step1"])
  end

  test "execute with pause flag will pause on the matching step" do
    @workflow.stubs(pause_step_name: "step1")
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("step1", step_key: "step1").returns(step_obj)
    mock_binding = mock("mock_binding")
    Kernel.stubs(:binding).returns(mock_binding)
    mock_binding.expects(:irb)
    @executor.execute_steps(["step1"])
  end

  test "executes string steps with interpolation" do
    @workflow.expects(:instance_eval).with("file").returns("test.rb")
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("step test.rb", step_key: "step test.rb").returns(step_obj)
    @executor.execute_steps(["step {{file}}"])
  end

  test "executes plain text prompts with configured model" do
    # This test verifies the fix for PR #60
    @config_hash["model"] = "gpt-4o"
    @executor = Roast::Workflow::WorkflowExecutor.new(@workflow, @config_hash, @context_path)

    transcript = []
    @workflow.stubs(:transcript).returns(transcript)
    @workflow.stubs(:resource).returns(nil)
    @workflow.stubs(:append_to_final_output)
    @workflow.stubs(:openai?).returns(true)
    @workflow.stubs(:tools).returns(nil)

    # Expect chat_completion to be called with the configured model
    # Now expects loop: false due to new BaseStep behavior
    @workflow.expects(:chat_completion).with(
      openai: "gpt-4o",
      model: "gpt-4o",
      json: false,
      params: {},
    ).returns("Test response")

    result = @executor.execute_step("this is a plain text prompt")
    assert_equal "Test response", result
  end

  # Hash steps tests
  test "executes hash steps" do
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("command1", step_key: "var1").returns(step_obj)
    @executor.execute_steps([{ "var1" => "command1" }])
    assert_equal "result", @output["var1"]
  end

  test "executes hash steps with interpolation in key" do
    @workflow.expects(:instance_eval).with("var_name").returns("test_var")
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("command1", step_key: "test_var").returns(step_obj)
    @executor.execute_steps([{ "{{var_name}}" => "command1" }])
    assert_equal "result", @output["test_var"]
  end

  test "executes hash steps with interpolation in value" do
    @workflow.expects(:instance_eval).with("cmd").returns("test_command")
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("test_command", step_key: "var1").returns(step_obj)
    @executor.execute_steps([{ "var1" => "{{cmd}}" }])
    assert_equal "result", @output["var1"]
  end

  test "executes hash steps with interpolation in both key and value" do
    @workflow.expects(:instance_eval).with("var_name").returns("test_var")
    @workflow.expects(:instance_eval).with("cmd").returns("test_command")
    step_obj = mock("step")
    step_obj.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with("test_command", step_key: "test_var").returns(step_obj)
    @executor.execute_steps([{ "{{var_name}}" => "{{cmd}}" }])
    assert_equal "result", @output["test_var"]
  end

  # Array steps (parallel execution) tests
  test "executes steps in parallel" do
    mock_thread1 = mock
    mock_thread1.expects(:join)
    mock_thread1.expects(:[]).with(:error).returns(nil)

    mock_thread2 = mock
    mock_thread2.expects(:join)
    mock_thread2.expects(:[]).with(:error).returns(nil)

    Thread.expects(:new).twice.returns(mock_thread1, mock_thread2)

    @executor.execute_steps([["step1", "step2"]])
  end

  # Unknown step type tests
  test "raises an error for unknown step type" do
    # The new architecture wraps the error in StepExecutionError
    assert_raises(Roast::Workflow::WorkflowExecutor::StepExecutionError) do
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
    @executor.step_loader.expects(:load).with(anything, anything).returns(step_obj)

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

    @executor.step_loader.expects(:load).with(anything, anything).raises(StandardError.new("test error"))

    assert_raises(Roast::Workflow::WorkflowExecutor::StepExecutionError) do
      @executor.execute_step("failing_step")
    end

    error_event = events.find { |e| e[:name] == "roast.step.error" }

    refute_nil error_event
    assert_equal "failing_step", error_event[:payload][:step_name]
    assert_equal "StandardError", error_event[:payload][:error]
    assert_match(/test error/, error_event[:payload][:message])
    assert_instance_of Float, error_event[:payload][:execution_time]

    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  # Bash expression tests
  test "executes shell command for bash expression" do
    # Instead of mocking the system call, mock at a higher level
    # Since command execution is delegated to CommandExecutor,
    # we need to check what actually happens
    @workflow.expects(:transcript).returns([]).at_least(1)

    # Let's actually let it run, but in a controlled environment
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("file1", "")
        File.write("file2", "")
        result = @executor.execute_step("$(ls)")
        assert_includes result, "file1"
        assert_includes result, "file2"
      end
    end
  end

  # Glob pattern tests
  test "expands glob pattern" do
    Dir.expects(:glob).with("*.rb").returns(["file1.rb", "file2.rb"])

    result = @executor.execute_step("*.rb")
    assert_equal "file1.rb\nfile2.rb", result
  end

  # Regular step tests
  test "loads and executes step object" do
    step_object = mock("step")
    step_object.expects(:call).returns("result")
    @executor.step_loader.expects(:load).with(anything, anything).returns(step_object)
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
    @workflow.expects(:transcript).returns([]).at_least(1)

    # Since rubocop command doesn't exist, let's use echo instead
    result = nil
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("test.rb", "# test file")
        result = @executor.execute_steps(["$(echo 'Processing {{file}}')"])
      end
    end

    # Verify interpolation happened (the result would contain "Processing test.rb")
    assert_not_nil result
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
