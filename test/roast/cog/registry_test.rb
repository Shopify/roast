# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class RegistryTest < ActiveSupport::TestCase
      def setup
        @registry = Registry.new
      end

      test "initialize registers system cogs" do
        assert @registry.cogs.key?(:call)
        assert @registry.cogs.key?(:map)
        assert @registry.cogs.key?(:repeat)
      end

      test "initialize registers standard cogs" do
        assert @registry.cogs.key?(:cmd)
        assert @registry.cogs.key?(:chat)
        assert @registry.cogs.key?(:agent)
        assert @registry.cogs.key?(:ruby)
      end

      test "use registers a cog class by derived name" do
        custom_cog = Class.new(Cog)
        # Give it a name by assigning to a constant
        self.class.const_set(:CustomTestCog, custom_cog)

        @registry.use(self.class::CustomTestCog)

        assert @registry.cogs.key?(:custom_test_cog)
        assert_equal self.class::CustomTestCog, @registry.cogs[:custom_test_cog]
      ensure
        self.class.send(:remove_const, :CustomTestCog) if self.class.const_defined?(:CustomTestCog)
      end

      test "use overwrites existing cog with same name" do
        first_cog = Class.new(Cog)
        second_cog = Class.new(Cog)
        self.class.const_set(:OverwriteCog, first_cog)

        @registry.use(self.class::OverwriteCog)
        assert_equal first_cog, @registry.cogs[:overwrite_cog]

        # Reassign constant to second cog class
        self.class.send(:remove_const, :OverwriteCog)
        self.class.const_set(:OverwriteCog, second_cog)

        @registry.use(self.class::OverwriteCog)
        assert_equal second_cog, @registry.cogs[:overwrite_cog]
      ensure
        self.class.send(:remove_const, :OverwriteCog) if self.class.const_defined?(:OverwriteCog)
      end

      test "use raises CouldNotDeriveCogNameError for anonymous class" do
        anonymous_cog = Class.new(Cog)

        assert_raises(Registry::CouldNotDeriveCogNameError) do
          @registry.use(anonymous_cog)
        end
      end

      test "use derives name from demodulized underscored class name" do
        # The standard cogs demonstrate this:
        # Roast::Cogs::Agent -> :agent
        # Roast::Cogs::Cmd -> :cmd
        assert_equal Cogs::Agent, @registry.cogs[:agent]
        assert_equal Cogs::Cmd, @registry.cogs[:cmd]
      end
    end
  end
end
