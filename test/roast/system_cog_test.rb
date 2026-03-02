# frozen_string_literal: true

require "test_helper"

module Roast
  class SystemCogTest < ActiveSupport::TestCase
    class TestSystemCog < SystemCog
      class Input < TestCogSupport::TestInput; end
    end

    class CustomParamsSystemCog < SystemCog
      class Input < TestCogSupport::TestInput; end

      class Params < SystemCog::Params
        attr_reader :custom_param

        def initialize(name, custom_param: nil)
          super(name)
          @custom_param = custom_param
        end
      end
    end

    test "params_class returns SystemCog::Params by default" do
      anonymous_cog = Class.new(SystemCog)

      assert_equal SystemCog::Params, anonymous_cog.params_class
    end

    test "params_class returns child Params when defined" do
      assert_equal CustomParamsSystemCog::Params, CustomParamsSystemCog.params_class
    end

    test "Params anonymous? returns false when name is provided" do
      params = SystemCog::Params.new(:my_cog)

      refute params.anonymous?
      assert_equal :my_cog, params.name
    end

    test "Params anonymous? returns true when name is nil" do
      params = SystemCog::Params.new(nil)

      assert params.anonymous?
      assert_kind_of Symbol, params.name
    end

    test "anonymous? is forwarded from initialize to Cog" do
      cog = TestSystemCog.new(:named_cog, ->(_input, _scope, _index) { "value" }, anonymous: false) do |_input, _config|
        TestCogSupport::TestOutput.new("done")
      end

      refute cog.anonymous?
    end

    test "anonymous? returns true when anonymous: true is passed" do
      cog = TestSystemCog.new(:fallback, ->(_input, _scope, _index) { "value" }, anonymous: true) do |_input, _config|
        TestCogSupport::TestOutput.new("done")
      end

      assert cog.anonymous?
    end

    test "execute calls the on_execute block with input and config" do
      cog = TestSystemCog.new(:test_cog, ->(_input, _scope, _index) { "value" }, anonymous: false) do |_input, _config|
        TestCogSupport::TestOutput.new("executed")
      end

      run_cog(cog)

      assert cog.succeeded?
      assert_equal "executed", cog.output.value
    end

    test "execute passes through the configured config object" do
      captured_config = nil
      custom_config = Cog::Config.new

      cog = TestSystemCog.new(:config_cog, ->(_input, _scope, _index) { "value" }, anonymous: false) do |_input, config|
        captured_config = config
        TestCogSupport::TestOutput.new("done")
      end

      run_cog(cog, config: custom_config)

      assert_same custom_config, captured_config
    end
  end
end
