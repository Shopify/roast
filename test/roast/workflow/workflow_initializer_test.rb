# frozen_string_literal: true

require "test_helper"
require "roast/workflow/workflow_initializer"
require "roast/workflow/configuration"
require "mocha/minitest"

class RoastWorkflowInitializerTest < ActiveSupport::TestCase
  def setup
    @workflow_path = fixture_file("workflow/workflow.yml")
    @configuration = Roast::Workflow::Configuration.new(@workflow_path)
    @initializer = Roast::Workflow::WorkflowInitializer.new(@configuration)

    # Stub out initializer loading to prevent side effects
    Roast::Initializers.stubs(:load_all)
  end

  def test_setup_loads_initializers_and_configures_tools
    Roast::Initializers.expects(:load_all)

    @initializer.setup
  end

  def test_includes_tools_when_configured
    @configuration.stubs(:tools).returns(["Roast::Tools::ReadFile", "Roast::Tools::Grep"])

    Roast::Workflow::BaseWorkflow.expects(:include).with(Raix::FunctionDispatch)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Roast::Helpers::FunctionCachingInterceptor)
    Roast::Workflow::BaseWorkflow.expects(:include).with(Roast::Tools::ReadFile, Roast::Tools::Grep)

    @initializer.setup
  end

  def test_does_not_include_tools_when_none_configured
    @configuration.stubs(:tools).returns([])

    Roast::Workflow::BaseWorkflow.expects(:include).never

    @initializer.setup
  end

  def test_configures_api_client_when_api_token_present_and_not_already_configured
    @configuration.stubs(:api_token).returns("test-token")
    @configuration.stubs(:api_provider).returns(:openai)

    # Stub Raix configuration to indicate no client is configured yet
    Raix.configuration.stubs(:openai_client).returns(nil)

    # When api_token is present and no client configured, configure the client
    OpenAI::Client.expects(:new).with(access_token: "test-token").returns(mock("OpenAI::Client"))

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
    # Skip this test if OpenRouter is not available
    if defined?(OpenRouter) && defined?(OpenRouter::Client)
      @configuration.stubs(:api_token).returns("test-token")
      @configuration.stubs(:api_provider).returns(:openrouter)

      # Stub Raix configuration to indicate no client is configured yet
      Raix.configuration.stubs(:openrouter_client).returns(nil)

      # When api_token is present and no client configured, configure the client
      OpenRouter::Client.expects(:new).with(access_token: "test-token").returns(mock("OpenRouter::Client"))
      @initializer.setup
    else
      skip("OpenRouter gem not available")
    end
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
end
