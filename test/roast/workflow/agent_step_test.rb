# frozen_string_literal: true

require "test_helper"

class RoastWorkflowAgentStepTest < ActiveSupport::TestCase
  def setup
    # Mock chat completion for regular prompt
    @mock_openai_client = mock
    @mock_openai_client.stubs(:chat).returns({
      "choices" => [{ "message" => { "content" => "Regular LLM response" } }],
    })
    OpenAI::Client.stubs(:new).returns(@mock_openai_client)

    # Store original env
    @original_openai_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
  end

  def teardown
    OpenAI::Client.unstub(:new)
    ENV["OPENAI_API_KEY"] = @original_openai_key
  end

  test "agent step type is recognized correctly" do
    assert Roast::Workflow::StepTypeResolver.agent_step?("^my_prompt")
    assert Roast::Workflow::StepTypeResolver.agent_step?("^Review the code and identify issues")
    refute Roast::Workflow::StepTypeResolver.agent_step?("my_prompt")
    refute Roast::Workflow::StepTypeResolver.agent_step?("$(command)")
  end

  test "extract_name strips ^ prefix for agent steps" do
    assert_equal "my_prompt", Roast::Workflow::StepTypeResolver.extract_name("^my_prompt")
    assert_equal "Review the code and identify issues", Roast::Workflow::StepTypeResolver.extract_name("^Review the code and identify issues")
    assert_equal "regular_prompt", Roast::Workflow::StepTypeResolver.extract_name("regular_prompt")
  end

  test "resolve returns AGENT_STEP for ^ prefixed steps" do
    step_type = Roast::Workflow::StepTypeResolver.resolve("^my_prompt")
    assert_equal Roast::Workflow::StepTypeResolver::AGENT_STEP, step_type
  end

  test "agent step loads AgentStep class when agent flag is true" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:model).returns(nil)

    # Create a temporary directory structure for the test
    Dir.mktmpdir do |tmpdir|
      # Create prompt directories
      agent_prompt_dir = File.join(tmpdir, "agent_prompt")
      regular_prompt_dir = File.join(tmpdir, "regular_prompt")
      Dir.mkdir(agent_prompt_dir)
      Dir.mkdir(regular_prompt_dir)

      # Create prompt files
      File.write(File.join(agent_prompt_dir, "prompt.md"), "Agent prompt content")
      File.write(File.join(regular_prompt_dir, "prompt.md"), "Regular prompt content")

      # Create step loader
      step_loader = Roast::Workflow::StepLoader.new(workflow, {}, tmpdir)

      # Load regular prompt step (with directory, it loads BaseStep)
      regular_step = step_loader.load("regular_prompt")
      assert_instance_of Roast::Workflow::BaseStep, regular_step

      # Load agent step (with directory and agent_type option, it loads AgentStep)
      agent_step = step_loader.load("agent_prompt", agent_type: :coding_agent)
      assert_instance_of Roast::Workflow::AgentStep, agent_step
    end
  end

  test "agent step calls CodingAgent directly without LLM translation" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")

    # Mock the prompt loader to return our test prompt
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test agent prompt")

    # Set expectation that CodingAgent will be called with the prompt and default options
    Roast::Tools::CodingAgent.expects(:call).with("Test agent prompt", include_context_summary: false, continue: false).returns("Agent response")

    # Execute the step
    result = agent_step.call

    # Verify the result
    assert_equal "Agent response", result
  end

  test "step executor coordinator handles agent steps" do
    # Create mock dependencies
    workflow = mock
    workflow.stubs(:output).returns({})
    workflow.stubs(:metadata).returns({})
    config_mock = mock
    config_mock.stubs(:workflow_path).returns("/test/workflow.yml")
    workflow.stubs(:config).returns(config_mock)

    state_manager = mock
    state_manager.stubs(:save_state)

    error_handler = Object.new
    def error_handler.with_error_handling(step_name, options = {})
      yield
    end

    step_loader = mock
    step_loader.expects(:load).with("my_prompt", exit_on_error: true, step_key: "my_prompt", is_last_step: nil, agent_type: :coding_agent, retries: 0).returns(mock.tap { |m| m.expects(:call).returns("agent result") })

    context = Roast::Workflow::WorkflowContext.new(
      workflow:,
      config_hash: {},
      context_path: "/test",
    )

    dependencies = {
      workflow_executor: mock,
      state_manager:,
      error_handler:,
      step_loader:,
    }

    coordinator = Roast::Workflow::StepExecutorCoordinator.new(context:, dependencies:)

    # Execute an agent step
    result = coordinator.execute("^my_prompt")
    assert_equal "agent result", result
  end

  test "inline agent prompts work with ^ prefix" do
    # Create mock dependencies
    workflow = mock
    workflow.stubs(:output).returns({})
    workflow.stubs(:metadata).returns({})
    config_mock = mock
    config_mock.stubs(:workflow_path).returns("/test/workflow.yml")
    workflow.stubs(:config).returns(config_mock)

    state_manager = mock
    state_manager.stubs(:save_state)

    error_handler = Object.new
    def error_handler.with_error_handling(step_name, options = {})
      yield
    end

    step_loader = mock

    # The inline prompt should have the ^ prefix stripped
    expected_prompt = "Review the code and identify any code smells"
    step_loader.expects(:load).with(expected_prompt, step_key: expected_prompt, exit_on_error: true, is_last_step: nil, agent_type: :coding_agent, retries: 0).returns(mock.tap { |m| m.expects(:call).returns("agent result") })

    context = Roast::Workflow::WorkflowContext.new(
      workflow:,
      config_hash: {},
      context_path: "/test",
    )

    dependencies = {
      workflow_executor: mock,
      state_manager:,
      error_handler:,
      step_loader:,
    }

    coordinator = Roast::Workflow::StepExecutorCoordinator.new(context:, dependencies:)

    # Execute an inline agent step
    result = coordinator.execute("^Review the code and identify any code smells")
    assert_equal "agent result", result
  end

  test "agent step handles inline prompts correctly" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with inline prompt
    inline_prompt = "Review this code and identify performance bottlenecks"
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: inline_prompt)

    # Set up expectation for CodingAgent call with the inline prompt and default options
    Roast::Tools::CodingAgent.expects(:call).with(inline_prompt, include_context_summary: false, continue: false).returns("Found 3 bottlenecks")

    # Execute the step
    result = agent_step.call

    # Verify the result
    assert_equal "Found 3 bottlenecks", result
  end

  test "agent step full integration test from workflow YAML" do
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: agent_test_workflow
        tools: []
        steps:
          - ^analyze the code and identify issues
          - ^refactor the problematic functions

        analyze the code and identify issues:
          include_context_summary: true
          continue: false

        refactor the problematic functions:
          include_context_summary: false#{" "}
          continue: true
      YAML

      # Create a Configuration from the YAML (like normal Roast execution)
      configuration = Roast::Workflow::Configuration.new(workflow_file)

      # Verify the configuration loaded correctly
      assert_equal "agent_test_workflow", configuration.name
      assert_equal ["^analyze the code and identify issues", "^refactor the problematic functions"], configuration.steps

      # Verify step configuration (without ^ prefix in config keys)
      step1_config = configuration.get_step_config("analyze the code and identify issues")
      assert_equal true, step1_config["include_context_summary"]
      assert_equal false, step1_config["continue"]

      step2_config = configuration.get_step_config("refactor the problematic functions")
      assert_equal false, step2_config["include_context_summary"]
      assert_equal true, step2_config["continue"]

      # Create a workflow from the configuration (like WorkflowRunner does)
      workflow = Roast::Workflow::BaseWorkflow.new(nil, name: configuration.name)

      # Create WorkflowExecutor with the parsed configuration
      executor = Roast::Workflow::WorkflowExecutor.new(
        workflow,
        configuration.config_hash,
        tmpdir,
      )

      # Mock CodingAgent calls to prevent actual LLM execution
      # First agent step should get config: include_context_summary=true, continue=false
      Roast::Tools::CodingAgent.expects(:call).with(
        "analyze the code and identify issues",
        include_context_summary: true,
        continue: false,
      ).returns("Found 3 issues: X, Y, Z")

      # Second agent step should get config: include_context_summary=false, continue=true
      Roast::Tools::CodingAgent.expects(:call).with(
        "refactor the problematic functions",
        include_context_summary: false,
        continue: true,
      ).returns("Refactored functions A, B, C")

      executor.execute_steps(configuration.steps)

      # Verify workflow output contains results from both agent steps
      assert_equal "Found 3 issues: X, Y, Z", workflow.output["analyze the code and identify issues"]
      assert_equal "Refactored functions A, B, C", workflow.output["refactor the problematic functions"]
    end
  end

  test "agent step parses JSON response when json: true" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return raw JSON string
    json_response = '{"results": ["item1", "item2"], "count": 2}'
    Roast::Tools::CodingAgent.expects(:call).returns(json_response)

    # Execute the step
    result = agent_step.call

    # Verify the result is parsed JSON, not a string
    assert_instance_of Hash, result
    assert_equal ["item1", "item2"], result["results"]
    assert_equal 2, result["count"]
  end

  test "agent step parses JSON wrapped in markdown code blocks" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return JSON wrapped in markdown
    markdown_response = <<~RESPONSE
      ```json
      {
        "files": ["test.rb", "main.rb"],
        "total": 2
      }
      ```
    RESPONSE

    Roast::Tools::CodingAgent.expects(:call).returns(markdown_response)

    # Execute the step
    result = agent_step.call

    # Verify the result is parsed JSON with markdown stripped
    assert_instance_of Hash, result
    assert_equal ["test.rb", "main.rb"], result["files"]
    assert_equal 2, result["total"]
  end

  test "agent step parses JSON wrapped in plain code blocks" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return JSON wrapped in plain code blocks
    plain_code_response = <<~RESPONSE
      ```
      ["test1", "test2", "test3"]
      ```
    RESPONSE

    Roast::Tools::CodingAgent.expects(:call).returns(plain_code_response)

    # Execute the step
    result = agent_step.call

    # Verify the result is parsed JSON array
    assert_instance_of Array, result
    assert_equal ["test1", "test2", "test3"], result
  end

  test "agent step raises error for invalid JSON when json: true" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return invalid JSON
    Roast::Tools::CodingAgent.expects(:call).returns("This is not valid JSON")

    # Execute the step and expect a JSON parsing error
    error = assert_raises(RuntimeError) do
      agent_step.call
    end

    assert_match(/Failed to parse CodingAgent result as JSON/, error.message)
  end

  test "agent step passes through error messages without parsing as JSON" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return error message
    error_message = "Error running CodingAgent: Something went wrong"
    Roast::Tools::CodingAgent.expects(:call).returns(error_message)

    # Execute the step and expect the error to be raised directly
    error = assert_raises(RuntimeError) do
      agent_step.call
    end

    assert_equal error_message, error.message
  end

  test "agent step returns string when json: false" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: false (default)
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = false

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate output")

    # Mock CodingAgent to return JSON string
    json_string = '{"results": ["item1", "item2"]}'
    Roast::Tools::CodingAgent.expects(:call).returns(json_string)

    # Execute the step
    result = agent_step.call

    # Verify the result is returned as-is (string), not parsed
    assert_instance_of String, result
    assert_equal json_string, result
  end

  test "agent step parses JSON code blocks anywhere in response" do
    # Create a mock workflow
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create agent step with json: true
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_agent")
    agent_step.json = true

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Generate JSON output")

    # Mock CodingAgent to return response with text around JSON code block
    response_with_text = <<~RESPONSE
      Here's my analysis of the code:

      I found several issues that need attention. Let me provide the detailed results:

      ```json
      {
        "issues": ["performance", "security", "maintainability"],
        "severity": "high",
        "recommendations": ["refactor loops", "sanitize input", "add tests"]
      }
      ```

      Please review these findings and let me know if you need clarification.
    RESPONSE

    Roast::Tools::CodingAgent.expects(:call).returns(response_with_text)

    # Execute the step
    result = agent_step.call

    # Verify the result is parsed JSON with surrounding text stripped
    assert_instance_of Hash, result
    assert_equal ["performance", "security", "maintainability"], result["issues"]
    assert_equal "high", result["severity"]
    assert_equal ["refactor loops", "sanitize input", "add tests"], result["recommendations"]
  end

  test "agent step handles resume option by copying session ID from referenced step" do
    # Create a mock workflow with metadata
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Set up metadata with session ID from previous step
    metadata = {
      "previous_step" => {
        "coding_agent_session_id" => "session-from-previous-123",
      },
    }
    workflow.stubs(:metadata).returns(metadata)

    # Create agent step with resume option
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "current_step")
    agent_step.resume = "previous_step"

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Continue working on the task")

    # Mock CodingAgent - should receive continue: true when resume is set
    Roast::Tools::CodingAgent.expects(:call).with(
      "Continue working on the task",
      include_context_summary: false,
      continue: true, # Should be true because resume is set
    ).returns("Continued from previous session")

    # Execute the step
    result = agent_step.call

    # Verify the session ID was copied to the current step's metadata
    assert_equal "session-from-previous-123", metadata["current_step"]["coding_agent_session_id"]
    assert_equal "Continued from previous session", result
  end

  test "agent step logs warning when resume step has no session ID" do
    # Create a mock workflow with metadata (no session ID for previous_step)
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Metadata without session ID
    metadata = {
      "previous_step" => {},
    }
    workflow.stubs(:metadata).returns(metadata)

    # Create agent step with resume option
    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "current_step")
    agent_step.resume = "previous_step"

    # Mock the prompt loader
    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Continue working on the task")

    # Expect warning log
    Roast::Helpers::Logger.expects(:warn).with("Cannot resume from step 'previous_step'. It does not have a coding_agent_session_id in its metadata.")

    # Mock CodingAgent - should not receive `continue: true` implied by `resume` because we don't have a session ID
    Roast::Tools::CodingAgent.expects(:call).with(
      "Continue working on the task",
      include_context_summary: false,
      continue: false,
    ).returns("Ran with --continue instead of --resume")

    # Execute the step
    result = agent_step.call

    # Verify no session ID was copied
    assert_nil metadata["current_step"]
    assert_equal "Ran with --continue instead of --resume", result
  end

  test "agent step passes continue true when either continue is set or resume is set with a session_id available" do
    # Test with continue: true, resume: nil
    workflow = mock
    workflow.stubs(:resource).returns(nil)
    workflow.stubs(:output).returns({})
    workflow.stubs(:transcript).returns([])
    workflow.stubs(:append_to_final_output)
    workflow.stubs(:file).returns(nil)
    workflow.stubs(:config).returns({})
    workflow.stubs(:model).returns(nil)

    # Create metadata with session ID for "some_step"
    metadata_with_session = {
      "some_step" => {
        "coding_agent_session_id" => "session-123",
      },
    }
    workflow.stubs(:metadata).returns(metadata_with_session)

    agent_step = Roast::Workflow::AgentStep.new(workflow, name: "test_step")
    agent_step.continue = true
    agent_step.resume = nil

    Roast::Helpers::PromptLoader.stubs(:load_prompt).returns("Test prompt")
    Roast::Tools::CodingAgent.expects(:call).with(
      "Test prompt",
      include_context_summary: false,
      continue: true,
    ).returns("Result")

    agent_step.call

    agent_step2 = Roast::Workflow::AgentStep.new(workflow, name: "test_step2")
    agent_step2.continue = false
    agent_step2.resume = "some_step"

    Roast::Tools::CodingAgent.expects(:call).with(
      "Test prompt",
      include_context_summary: false,
      continue: true, # Should be true because resume is set and a session_id is available
    ).returns("Result")

    agent_step2.call

    # Verify the session ID was copied
    assert_equal "session-123", metadata_with_session["test_step2"]["coding_agent_session_id"]
  end

  test "agent step full integration test with resume functionality" do
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, <<~YAML)
        name: resume_test_workflow
        tools: []
        steps:
          - ^analyze the code
          - ^refactor based on analysis
          - ^polish the refactoring

        analyze the code:
          continue: false

        refactor based on analysis:
          continue: true

        polish the refactoring:
          resume: "analyze the code"
      YAML

      # Create a Configuration from the YAML
      configuration = Roast::Workflow::Configuration.new(workflow_file)

      # Create a workflow from the configuration
      workflow = Roast::Workflow::BaseWorkflow.new(nil, name: configuration.name)

      # Initialize metadata
      workflow.metadata["analyze the code"] = {
        "coding_agent_session_id" => "initial-session-789",
      }

      # Create WorkflowExecutor
      executor = Roast::Workflow::WorkflowExecutor.new(
        workflow,
        configuration.config_hash,
        tmpdir,
      )

      # Mock CodingAgent calls
      # First step - no continue
      Roast::Tools::CodingAgent.expects(:call).with(
        "analyze the code",
        include_context_summary: false,
        continue: false,
      ).returns("Analysis complete")

      # Second step - continue: true
      Roast::Tools::CodingAgent.expects(:call).with(
        "refactor based on analysis",
        include_context_summary: false,
        continue: true,
      ).returns("Refactoring done")

      # Third step - resume from first step
      Roast::Tools::CodingAgent.expects(:call).with(
        "polish the refactoring",
        include_context_summary: false,
        continue: true, # True because resume is set
      ).returns("Polishing complete")

      executor.execute_steps(configuration.steps)

      # Verify outputs
      assert_equal "Analysis complete", workflow.output["analyze the code"]
      assert_equal "Refactoring done", workflow.output["refactor based on analysis"]
      assert_equal "Polishing complete", workflow.output["polish the refactoring"]

      # Verify metadata was copied for resume
      assert_equal "initial-session-789", workflow.metadata["polish the refactoring"]["coding_agent_session_id"]
    end
  end
end
