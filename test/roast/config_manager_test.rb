# frozen_string_literal: true

require "test_helper"

module Roast
  class ConfigManagerTest < ActiveSupport::TestCase
    class TestCogConfig < Cog::Config
      field :timeout, 30
    end

    class TestCog < Cog
      class Config < TestCogConfig; end

      def execute(_input)
        raise NotImplementedError
      end
    end

    def setup
      @registry = Cog::Registry.new
      @registry.use(TestCog)
    end

    test "prepare! transitions to prepared state" do
      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)

      refute manager.prepared?
      manager.prepare!
      assert manager.prepared?
    end

    test "prepare! raises when called twice" do
      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)
      manager.prepare!

      assert_raises(ConfigManager::ConfigManagerAlreadyPreparedError) do
        manager.prepare!
      end
    end

    test "prepare! evaluates config procs in the config context" do
      timeout_set = false
      config_proc = proc do
        test_cog { timeout 60 }
        timeout_set = true
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      assert timeout_set
    end

    test "config_for raises when not prepared" do
      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)

      assert_raises(ConfigManager::ConfigManagerNotPreparedError) do
        manager.config_for(TestCog)
      end
    end

    test "config_for returns default config when no config procs are provided" do
      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)
      manager.prepare!

      config = manager.config_for(TestCog)

      assert_equal 30, config.timeout
    end

    test "config_for applies general cog configuration" do
      config_proc = proc do
        test_cog { timeout 60 }
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      config = manager.config_for(TestCog)

      assert_equal 60, config.timeout
    end

    test "config_for applies name-scoped configuration" do
      config_proc = proc do
        test_cog(:my_step) { timeout 90 }
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      scoped_config = manager.config_for(TestCog, :my_step)
      unscoped_config = manager.config_for(TestCog, :other_step)

      assert_equal 90, scoped_config.timeout
      assert_equal 30, unscoped_config.timeout
    end

    test "config_for applies regexp-scoped configuration" do
      config_proc = proc do
        test_cog(/^api_/) { timeout 120 }
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      matching_config = manager.config_for(TestCog, :api_call)
      non_matching_config = manager.config_for(TestCog, :db_query)

      assert_equal 120, matching_config.timeout
      assert_equal 30, non_matching_config.timeout
    end

    test "config_for merges general and name-scoped configs" do
      config_proc = proc do
        test_cog { async! }
        test_cog(:my_step) { timeout 90 }
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      config = manager.config_for(TestCog, :my_step)

      assert config.async?
      assert_equal 90, config.timeout
    end

    test "config_for applies global config to all cogs" do
      config_proc = proc do
        global { abort_on_failure! }
      end
      manager = ConfigManager.new(@registry, [config_proc], ProviderRegistry.new)
      manager.prepare!

      config = manager.config_for(TestCog)

      assert config.abort_on_failure?
    end

    test "config_for injects provider registry into Agent::Config" do
      registry = Cog::Registry.new
      provider_registry = ProviderRegistry.new
      provider_registry.register(Cogs::Agent::Providers::Claude, :claude)

      manager = ConfigManager.new(registry, [], provider_registry)
      manager.prepare!

      config = manager.config_for(Cogs::Agent)

      assert_equal provider_registry, config.instance_variable_get(:@provider_registry)
    end

    test "config_for does not inject provider registry into non-Agent configs" do
      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)
      manager.prepare!

      config = manager.config_for(TestCog)

      refute config.respond_to?(:provider_registry)
      refute config.instance_variable_defined?(:@provider_registry)
    end

    test "prepare! raises IllegalCogNameError when cog name conflicts with existing method" do
      # Register a cog whose derived name ("freeze") conflicts with Object#freeze
      conflicting_cog = Class.new(Cog) do
        class << self
          def name
            "Roast::TestCogs::Freeze"
          end
        end
      end
      @registry.use(conflicting_cog)

      manager = ConfigManager.new(@registry, [], ProviderRegistry.new)

      assert_raises(ConfigManager::IllegalCogNameError) do
        manager.prepare!
      end
    end
  end
end
