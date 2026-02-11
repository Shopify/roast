# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class ProviderTest < ActiveSupport::TestCase
        def setup
          @config = Config.new
          @provider = Provider.new(@config)
        end

        test "initialize stores config" do
          assert_equal @config, @provider.instance_variable_get(:@config)
        end

        test "invoke raises NotImplementedError" do
          input = Input.new

          error = assert_raises(NotImplementedError) do
            @provider.invoke(input)
          end

          assert_equal "Subclasses must implement #invoke", error.message
        end

        test "subclass can override invoke" do
          subclass = Class.new(Provider) do
            def invoke(input)
              output = Output.new
              output.instance_variable_set(:@response, "Test response")
              output
            end
          end

          provider = subclass.new(@config)
          input = Input.new
          output = provider.invoke(input)

          assert_equal "Test response", output.response
        end
      end

      class ProviderRegistryTest < ActiveSupport::TestCase
        def setup
          @original_registry = Provider.instance_variable_get(:@registry)&.dup
          @original_default = Provider.instance_variable_get(:@default_provider_name)
          Provider.instance_variable_set(:@registry, {})
          Provider.instance_variable_set(:@default_provider_name, nil)
          Provider.instance_variable_set(:@initialized, false)
        end

        def teardown
          Provider.instance_variable_set(:@registry, @original_registry)
          Provider.instance_variable_set(:@default_provider_name, @original_default)
          Provider.instance_variable_set(:@initialized, true)
        end

        test "register adds a provider to the registry" do
          provider_class = Class.new(Provider)
          Provider.register(:test_provider, provider_class)

          assert Provider.registered?(:test_provider)
        end

        test "resolve returns the registered class" do
          provider_class = Class.new(Provider)
          Provider.register(:test_provider, provider_class)

          assert_equal provider_class, Provider.resolve(:test_provider)
        end

        test "resolve returns nil for unknown providers" do
          assert_nil Provider.resolve(:nonexistent)
        end

        test "registered? returns true for registered providers" do
          provider_class = Class.new(Provider)
          Provider.register(:test_provider, provider_class)

          assert Provider.registered?(:test_provider)
        end

        test "registered? returns false for unregistered providers" do
          refute Provider.registered?(:nonexistent)
        end

        test "registered_provider_names lists all registered names" do
          provider_a = Class.new(Provider)
          provider_b = Class.new(Provider)
          Provider.register(:alpha, provider_a)
          Provider.register(:beta, provider_b)

          assert_includes Provider.registered_provider_names, :alpha
          assert_includes Provider.registered_provider_names, :beta
        end

        test "default_provider_name returns the provider marked as default" do
          provider_a = Class.new(Provider)
          provider_b = Class.new(Provider)
          Provider.register(:alpha, provider_a)
          Provider.register(:beta, provider_b, default: true)

          assert_equal :beta, Provider.default_provider_name
        end

        test "default_provider_name can be overridden by registering a new default" do
          provider_class = Class.new(Provider)
          Provider.register(:custom, provider_class, default: true)

          assert_equal :custom, Provider.default_provider_name
        end

        test "Claude is registered as default after initialization" do
          assert Provider.registered?(:claude)
          assert_equal :claude, Provider.default_provider_name
          assert_equal Providers::Claude, Provider.resolve(:claude)
        end
      end
    end
  end
end
