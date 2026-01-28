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
    end
  end
end
