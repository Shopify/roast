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

    test "execute calls the on_execute block with input and config" do
      cog = TestSystemCog.new(:test_cog, ->(_input, _scope, _index) { "value" }) do |_input, _config|
        TestCogSupport::TestOutput.new("executed")
      end

      run_cog(cog)

      assert cog.succeeded?
      assert_equal "executed", cog.output.value
    end

    test "execute passes through the configured config object" do
      captured_config = nil
      custom_config = Cog::Config.new

      cog = TestSystemCog.new(:config_cog, ->(_input, _scope, _index) { "value" }) do |_input, config|
        captured_config = config
        TestCogSupport::TestOutput.new("done")
      end

      run_cog(cog, config: custom_config)

      assert_same custom_config, captured_config
    end
  end
end
