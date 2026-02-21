# frozen_string_literal: true

require "test_helper"

module Roast
  class ProviderRegistryTest < ActiveSupport::TestCase
    class MockProvider < Cogs::Agent::Provider
      def invoke(input)
        raise NotImplementedError
      end
    end

    class CustomProvider < Cogs::Agent::Provider
      def invoke(input)
        raise NotImplementedError
      end
    end

    def setup
      @registry = ProviderRegistry.new
    end

    test "register adds provider with auto-generated name" do
      @registry.register(MockProvider)

      assert @registry.exists?(:mock_provider)
      assert_equal MockProvider, @registry.fetch(:mock_provider)
    end

    test "register adds provider with explicit name" do
      @registry.register(MockProvider, :custom_name)

      assert @registry.exists?(:custom_name)
      assert_equal MockProvider, @registry.fetch(:custom_name)
    end

    test "register raises DuplicateProviderNameError when name already exists" do
      @registry.register(MockProvider, :duplicate)

      assert_raises(ProviderRegistry::DuplicateProviderNameError) do
        @registry.register(CustomProvider, :duplicate)
      end
    end

    test "fetch returns the registered provider class" do
      @registry.register(MockProvider)

      provider_class = @registry.fetch(:mock_provider)

      assert_equal MockProvider, provider_class
    end

    test "fetch uses default when name is nil" do
      @registry.register(MockProvider)
      @registry.default = :mock_provider

      provider_class = @registry.fetch(nil)

      assert_equal MockProvider, provider_class
    end

    test "fetch raises ProviderNotFoundError when provider does not exist" do
      assert_raises(ProviderRegistry::ProviderNotFoundError) do
        @registry.fetch(:nonexistent)
      end
    end

    test "fetch raises ProviderNotFoundError when default is not set and name is nil" do
      assert_raises(ProviderRegistry::ProviderNotFoundError) do
        @registry.fetch(nil)
      end
    end

    test "exists? returns true when provider is registered" do
      @registry.register(MockProvider)

      assert @registry.exists?(:mock_provider)
    end

    test "exists? returns false when provider is not registered" do
      refute @registry.exists?(:nonexistent)
    end

    test "prepare! registers Claude provider" do
      @registry.prepare!

      assert @registry.exists?(:claude)
      assert_equal Roast::Cogs::Agent::Providers::Claude, @registry.fetch(:claude)
    end

    test "prepare! sets default to claude" do
      @registry.prepare!

      assert_equal :claude, @registry.default
    end

    test "default attribute can be set and retrieved" do
      @registry.default = :custom_default

      assert_equal :custom_default, @registry.default
    end

    test "register with blank name uses auto-generated name" do
      @registry.register(CustomProvider, nil)

      assert @registry.exists?(:custom_provider)
    end

    test "register with empty string name uses auto-generated name" do
      @registry.register(CustomProvider, "")

      assert @registry.exists?(:custom_provider)
    end

    test "register allows same provider with different names" do
      @registry.register(MockProvider, :name1)
      @registry.register(MockProvider, :name2)

      assert_equal @registry.fetch(:name1), @registry.fetch(:name2)
    end
  end
end
