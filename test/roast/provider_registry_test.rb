# frozen_string_literal: true

require "test_helper"

module Roast
  class ProviderRegistryTest < ActiveSupport::TestCase
    def setup
      @registry = ProviderRegistry.new
    end

    test "register stores a provider class by derived name" do
      @registry.register(Cogs::Agent::Providers::Claude)

      assert_equal Cogs::Agent::Providers::Claude, @registry.fetch(:claude)
    end

    test "register uses explicit name when provided" do
      @registry.register(Cogs::Agent::Providers::Claude, :custom_name)

      assert_equal Cogs::Agent::Providers::Claude, @registry.fetch(:custom_name)
    end

    test "register derives name from demodulized underscored class name" do
      provider = Class.new(Cogs::Agent::Provider)
      stub_name = "Roast::Cogs::Agent::Providers::MyCustomProvider"
      provider.define_singleton_method(:name) { stub_name }

      @registry.register(provider)

      assert_equal provider, @registry.fetch(:my_custom_provider)
    end

    test "register raises DuplicateProviderNameError for duplicate derived name" do
      @registry.register(Cogs::Agent::Providers::Claude)

      assert_raises(ProviderRegistry::DuplicateProviderNameError) do
        @registry.register(Cogs::Agent::Providers::Claude)
      end
    end

    test "register raises DuplicateProviderNameError for duplicate explicit name" do
      @registry.register(Cogs::Agent::Providers::Claude, :my_provider)

      other_provider = Class.new(Cogs::Agent::Provider)
      other_provider.define_singleton_method(:name) { "OtherProvider" }

      assert_raises(ProviderRegistry::DuplicateProviderNameError) do
        @registry.register(other_provider, :my_provider)
      end
    end

    test "fetch raises ProviderNotFoundError for unregistered provider" do
      assert_raises(ProviderRegistry::ProviderNotFoundError) do
        @registry.fetch(:nonexistent)
      end
    end

    test "default is :claude when env var is not set" do
      with_env("ROAST_DEFAULT_AGENT", nil) do
        registry = ProviderRegistry.new
        assert_equal :claude, registry.default
      end
    end

    test "default reads from ROAST_DEFAULT_AGENT env var" do
      with_env("ROAST_DEFAULT_AGENT", "openai") do
        registry = ProviderRegistry.new
        assert_equal :openai, registry.default
      end
    end

    test "default is writable" do
      @registry.default = :openai

      assert_equal :openai, @registry.default
    end

    test "register multiple distinct providers" do
      first_provider = Class.new(Cogs::Agent::Provider)
      first_provider.define_singleton_method(:name) { "FirstProvider" }

      second_provider = Class.new(Cogs::Agent::Provider)
      second_provider.define_singleton_method(:name) { "SecondProvider" }

      @registry.register(first_provider)
      @registry.register(second_provider)

      assert_equal first_provider, @registry.fetch(:first_provider)
      assert_equal second_provider, @registry.fetch(:second_provider)
    end

    test "fetch with nil name returns provider registered under default" do
      @registry.register(Cogs::Agent::Providers::Claude, :claude)

      assert_equal Cogs::Agent::Providers::Claude, @registry.fetch(nil)
    end

    test "fetch with nil name uses custom default when set" do
      provider = Class.new(Cogs::Agent::Provider)
      provider.define_singleton_method(:name) { "CustomProvider" }

      @registry.register(provider, :custom)
      @registry.default = :custom

      assert_equal provider, @registry.fetch(nil)
    end

    test "key? returns true for registered provider" do
      @registry.register(Cogs::Agent::Providers::Claude)

      assert @registry.key?(:claude)
    end

    test "key? returns false for unregistered provider" do
      refute @registry.key?(:nonexistent)
    end
  end
end
