# frozen_string_literal: true

require "test_helper"

class RoastWorkflowInitializerTest < ActiveSupport::TestCase
  def setup
    @original_openai_key = ENV.delete("OPENAI_API_KEY")
    @workflow_path = fixture_file("workflow/workflow.yml")
    @configuration = Roast::Workflow::Configuration.new(@workflow_path)
    @initializer = Roast::Workflow::WorkflowInitializer.new(@configuration)

    # Stub out initializer loading to prevent side effects
    Roast::Initializers.stubs(:load_all)
  end

  def teardown
    ENV["OPENAI_API_KEY"] = @original_openai_key
  end

  def test_setup_loads_initializers_and_configures_tools
    Roast::Initializers.expects(:load_all)

    @initializer.setup
  end

  def test_includes_local_tools_when_configured
    @configuration.stubs(:tools).returns(["Roast::Tools::ReadFile", "Roast::Tools::Grep"])
    @configuration.stubs(:mcp_tools).returns([])

    Roast::Workflow::BaseWorkflow.expects(:include).with(Raix::FunctionDispatch)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Roast::Helpers::FunctionCachingInterceptor)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Roast::Tools::ReadFile, Roast::Tools::Grep)

    @initializer.setup
  end

  def test_does_not_include_local_tools_when_none_configured
    @configuration.stubs(:tools).returns([])
    @configuration.stubs(:mcp_tools).returns([])

    Roast::Workflow::BaseWorkflow.expects(:include).never

    @initializer.setup
  end

  def test_includes_mcp_tools_when_configured
    mock_client = mock("client")
    @configuration.stubs(:tools).returns([])
    @configuration.stubs(:mcp_tools).returns([
      Roast::Workflow::Configuration::MCPTool.new(
        name: "TestTool",
        config: {
          "command" => "echo",
          "args" => ["test"],
        },
        only: ["get_issue", "get_issue_comments"],
        except: nil,
      ),
    ])

    # Stub the client creation
    Raix::MCP::StdioClient.stubs(:new).with("echo", "test", {}).returns(mock_client)

    Roast::Workflow::BaseWorkflow.expects(:include).with(Raix::FunctionDispatch)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Roast::Helpers::FunctionCachingInterceptor)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Raix::MCP)
    Roast::Workflow::BaseWorkflow.expects(:mcp).with(client: mock_client, only: ["get_issue", "get_issue_comments"], except: nil)

    @initializer.setup
  end

  def test_does_not_include_mcp_tools_when_none_configured
    @configuration.stubs(:tools).returns([])
    @configuration.stubs(:mcp_tools).returns([])

    Roast::Workflow::BaseWorkflow.expects(:include).never

    @initializer.setup
  end

  def test_configures_api_client_when_api_token_present_and_not_already_configured
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openai)

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openai_client).returns(nil)

    # Mock successful client creation and validation
    mock_client = mock("OpenAI::Client")
    mock_models = mock("models")
    mock_client.stubs(:models).returns(mock_models)
    mock_models.stubs(:list).returns([])

    OpenAI::Client.expects(:new).with({ access_token: "test-token" }).returns(mock_client)

    @initializer.setup
  end

  def test_configures_api_client_with_uri_base
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openai)
    @configuration.stubs(:uri_base).returns(Roast::ValueObjects::UriBase.new("https://custom-api.example.com"))

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openai_client).returns(nil)

    # Mock successful client creation and validation
    mock_client = mock("OpenAI::Client")
    mock_models = mock("models")
    mock_client.stubs(:models).returns(mock_models)
    mock_models.stubs(:list).returns([])

    OpenAI::Client.expects(:new).with({
      access_token: "test-token",
      uri_base: "https://custom-api.example.com",
    }).returns(mock_client)

    @initializer.setup
  end

  def test_skips_api_client_configuration_when_already_configured
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openai)

    # Stub Raix configuration to indicate client is already configured
    Raix.configuration.stubs(:openai_client).returns(mock("OpenAI::Client"))

    # Should not try to create a new client when one already exists
    OpenAI::Client.expects(:new).never

    @initializer.setup
  end

  def test_configures_openrouter_client_when_api_token_present_and_not_already_configured
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openrouter)

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openrouter_client).returns(nil)

    # Mock successful client creation and validation
    mock_client = mock("OpenRouter::Client")
    mock_models = mock("models")
    mock_client.stubs(:models).returns(mock_models)
    mock_models.stubs(:list).returns([])

    OpenRouter::Client.expects(:new).with({ access_token: "test-token" }).returns(mock_client)
    @initializer.setup
  end

  def test_configures_openrouter_client_with_uri_base
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openrouter)
    @configuration.stubs(:uri_base).returns(Roast::ValueObjects::UriBase.new("https://custom-api.example.com"))

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openrouter_client).returns(nil)

    # Mock successful client creation and validation
    mock_client = mock("OpenRouter::Client")
    mock_models = mock("models")
    mock_client.stubs(:models).returns(mock_models)
    mock_models.stubs(:list).returns([])

    OpenRouter::Client.expects(:new).with({
      access_token: "test-token",
      uri_base: "https://custom-api.example.com",
    }).returns(mock_client)

    @initializer.setup
  end

  def test_skips_configuration_when_no_api_token
    @configuration.stubs(:api_token).returns(nil)
    @configuration.stubs(:api_provider).returns(:openai)

    # When no token is provided, skip configuration (assume initializer handles it)
    OpenAI::Client.expects(:new).never
    Roast::Helpers::Logger.expects(:error).never

    @initializer.setup
  end

  def test_skips_configuration_when_blank_api_token
    @configuration.stubs(:api_token).returns("")
    @configuration.stubs(:api_provider).returns(:openai)

    # When token is blank, skip configuration (assume initializer handles it)
    OpenAI::Client.expects(:new).never
    Roast::Helpers::Logger.expects(:error).never

    @initializer.setup
  end

  def test_raises_error_for_unsupported_api_provider_when_token_present
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:unsupported)

    Roast::Helpers::Logger.expects(:error).with("Error configuring API client: Unsupported api_provider in workflow configuration: unsupported")

    assert_raises(RuntimeError) do
      @initializer.setup
    end
  end

  def test_skips_configuration_for_unsupported_api_provider_when_no_token
    @configuration.stubs(:api_token).returns(nil)
    @configuration.stubs(:api_provider).returns(:unsupported)

    # When no token is provided, skip configuration even for unsupported providers
    Roast::Helpers::Logger.expects(:error).never

    @initializer.setup
  end

  def test_raises_authentication_error_when_api_token_invalid
    @configuration.stubs(:api_token).returns("invalid-token")
    @configuration.stubs(:api_provider).returns(:openai)
    @configuration.stubs(:openai?).returns(true)
    @configuration.stubs(:openrouter?).returns(false)

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openai_client).returns(nil)

    # Mock client that raises unauthorized error on validation
    mock_client = mock("OpenAI::Client")
    mock_models = mock("models")
    mock_client.stubs(:models).returns(mock_models)
    mock_models.stubs(:list).raises(Faraday::UnauthorizedError.new(nil))

    OpenAI::Client.expects(:new).with({ access_token: "invalid-token" }).returns(mock_client)

    ActiveSupport::Notifications.expects(:instrument).with(
      "roast.workflow.start.error",
      has_entries(
        error: "Roast::Errors::AuthenticationError",
        message: ":openai provider requires the OPENAI_API_KEY environment variable to be present, but not found",
      ),
    ).once

    error = assert_raises(Roast::Errors::AuthenticationError) do
      @initializer.setup
    end

    assert_equal(":openai provider requires the OPENAI_API_KEY environment variable to be present, but not found", error.message)
  end

  def test_handles_openrouter_configuration_error
    @configuration.stubs(:api_token).returns("invalid-format-token")
    @configuration.stubs(:api_provider).returns(:openrouter)
    @configuration.stubs(:openrouter?).returns(true)
    @configuration.stubs(:openai?).returns(false)

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openrouter_client).returns(nil)

    # Mock OpenRouter client that raises configuration error
    OpenRouter::Client.expects(:new).with({ access_token: "invalid-format-token" }).raises(OpenRouter::ConfigurationError.new("Invalid access token format"))

    ActiveSupport::Notifications.expects(:instrument).with(
      "roast.workflow.start.error",
      has_entries(
        error: "Roast::Errors::AuthenticationError",
        message: ":openrouter provider requires the OPENROUTER_API_KEY environment variable to be present, but not found",
      ),
    ).once

    error = assert_raises(Roast::Errors::AuthenticationError) do
      @initializer.setup
    end

    assert_equal(":openrouter provider requires the OPENROUTER_API_KEY environment variable to be present, but not found", error.message)
  end
end
