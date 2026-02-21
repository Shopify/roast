# frozen_string_literal: true

require "test_helper"

module Roast
  class WorkflowContextTest < ActiveSupport::TestCase
    class TestProvider < Cogs::Agent::Provider
      def invoke(input)
        "test response"
      end
    end

    class AnotherProvider < Cogs::Agent::Provider
      def invoke(input)
        "another response"
      end
    end

    def setup
      @params = WorkflowParams.new([], [], {})
      @tmpdir = "/tmp/test"
      @workflow_dir = Pathname.new("/test/workflow")
      @context = WorkflowContext.new(params: @params, tmpdir: @tmpdir, workflow_dir: @workflow_dir)
      @config = Cogs::Agent::Config.new
    end

    test "register_agent_provider registers provider with auto-generated name" do
      @context.register_agent_provider(TestProvider)

      provider = @context.agent_provider(:test_provider, @config)

      assert_instance_of TestProvider, provider
    end

    test "register_agent_provider registers provider with explicit name" do
      @context.register_agent_provider(TestProvider, :custom_name)

      provider = @context.agent_provider(:custom_name, @config)

      assert_instance_of TestProvider, provider
    end

    test "register_agent_provider with nil name uses auto-generated name" do
      @context.register_agent_provider(AnotherProvider, nil)

      provider = @context.agent_provider(:another_provider, @config)

      assert_instance_of AnotherProvider, provider
    end

    test "agent_provider returns new instance of registered provider" do
      @context.register_agent_provider(TestProvider)

      provider1 = @context.agent_provider(:test_provider, @config)
      provider2 = @context.agent_provider(:test_provider, @config)

      assert_instance_of TestProvider, provider1
      assert_instance_of TestProvider, provider2
      refute_same provider1, provider2
    end

    test "agent_provider raises error when provider not found" do
      assert_raises(ProviderRegistry::ProviderNotFoundError) do
        @context.agent_provider(:nonexistent, @config)
      end
    end

    test "multiple providers can be registered" do
      @context.register_agent_provider(TestProvider, :test)
      @context.register_agent_provider(AnotherProvider, :another)

      test_provider = @context.agent_provider(:test, @config)
      another_provider = @context.agent_provider(:another, @config)

      assert_instance_of TestProvider, test_provider
      assert_instance_of AnotherProvider, another_provider
    end

    test "register_agent_provider raises error for duplicate names" do
      @context.register_agent_provider(TestProvider, :duplicate)

      assert_raises(ProviderRegistry::DuplicateProviderNameError) do
        @context.register_agent_provider(AnotherProvider, :duplicate)
      end
    end

    test "params attribute is accessible" do
      assert_equal @params, @context.params
    end

    test "tmpdir attribute is accessible" do
      assert_equal @tmpdir, @context.tmpdir
    end

    test "workflow_dir attribute is accessible" do
      assert_equal @workflow_dir, @context.workflow_dir
    end

    test "provider_registry attribute not accessible" do
      assert_raises NoMethodError do
        @context.provider_registry
      end
    end
  end
end
