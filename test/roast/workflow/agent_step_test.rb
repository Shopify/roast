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
    config_mock = mock
    config_mock.stubs(:workflow_path).returns("/test/workflow.yml")
    workflow.stubs(:config).returns(config_mock)

    state_manager = mock
    state_manager.stubs(:save_state)

    error_handler = mock
    error_handler.stubs(:with_error_handling).yields

    step_orchestrator = mock
    step_orchestrator.expects(:execute_step).with("my_prompt", exit_on_error: true, step_key: nil, agent_type: :coding_agent).returns("agent result")

    context = Roast::Workflow::WorkflowContext.new(
      workflow:,
      config_hash: {},
      context_path: "/test",
    )

    dependencies = {
      workflow_executor: mock,
      state_manager:,
      error_handler:,
      step_orchestrator:,
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
    config_mock = mock
    config_mock.stubs(:workflow_path).returns("/test/workflow.yml")
    workflow.stubs(:config).returns(config_mock)

    state_manager = mock
    state_manager.stubs(:save_state)

    error_handler = mock
    error_handler.stubs(:with_error_handling).yields

    step_orchestrator = mock

    # The inline prompt should have the ^ prefix stripped
    expected_prompt = "Review the code and identify any code smells"
    step_orchestrator.expects(:execute_step).with(expected_prompt, exit_on_error: true, step_key: nil, agent_type: :coding_agent).returns("agent result")

    context = Roast::Workflow::WorkflowContext.new(
      workflow:,
      config_hash: {},
      context_path: "/test",
    )

    dependencies = {
      workflow_executor: mock,
      state_manager:,
      error_handler:,
      step_orchestrator:,
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
end
