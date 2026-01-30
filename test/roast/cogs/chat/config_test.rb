# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Chat < Cog
      class ConfigTest < ActiveSupport::TestCase
        def setup
          @config = Config.new
        end

        # Provider configuration tests
        test "provider sets provider value" do
          @config.provider(:openai)

          assert_equal :openai, @config.valid_provider!
        end

        test "use_default_provider! clears provider value" do
          @config.provider(:custom_provider)
          @config.use_default_provider!

          assert_equal :openai, @config.valid_provider!
        end

        test "valid_provider! returns default when not set" do
          assert_equal :openai, @config.valid_provider!
        end

        test "valid_provider! raises on invalid provider" do
          @config.provider(:invalid_provider)

          error = assert_raises(ArgumentError) do
            @config.valid_provider!
          end

          assert_match(/invalid_provider.*not a valid provider/, error.message)
        end

        # API key configuration tests
        test "api_key sets api key value" do
          @config.api_key("test-key-123")

          assert_equal "test-key-123", @config.valid_api_key!
        end

        test "use_api_key_from_environment! clears explicit api key" do
          @config.api_key("explicit-key")
          @config.use_api_key_from_environment!

          with_env("OPENAI_API_KEY", nil) do
            error = assert_raises(Cog::Config::InvalidConfigError) do
              @config.valid_api_key!
            end
            assert_equal "no api key provided", error.message
          end
        end

        test "valid_api_key! returns environment value when not explicitly set" do
          with_env("OPENAI_API_KEY", "env-api-key") do
            assert_equal "env-api-key", @config.valid_api_key!
          end
        end

        test "valid_api_key! raises when no api key provided" do
          with_env("OPENAI_API_KEY", nil) do
            error = assert_raises(Cog::Config::InvalidConfigError) do
              @config.valid_api_key!
            end
            assert_equal "no api key provided", error.message
          end
        end

        # Base URL configuration tests
        test "base_url sets base url value" do
          @config.base_url("https://custom.api.com/v1")

          assert_equal "https://custom.api.com/v1", @config.valid_base_url
        end

        test "use_default_base_url! clears explicit base url" do
          @config.base_url("https://custom.api.com/v1")
          @config.use_default_base_url!

          assert_equal "https://api.openai.com/v1", @config.valid_base_url
        end

        test "valid_base_url returns default when not set" do
          assert_equal "https://api.openai.com/v1", @config.valid_base_url
        end

        test "valid_base_url returns environment value when set" do
          with_env("OPENAI_API_BASE", "https://env.api.com/v1") do
            assert_equal "https://env.api.com/v1", @config.valid_base_url
          end
        end

        # Model configuration tests
        test "model sets model value" do
          @config.model("gpt-4")

          assert_equal "gpt-4", @config.valid_model
        end

        test "use_default_model! clears model value" do
          @config.model("gpt-4")
          @config.use_default_model!

          # use_default_model! sets value to nil, which valid_model returns
          # (nil means use provider's default at runtime)
          assert_nil @config.valid_model
        end

        test "valid_model returns default when not set" do
          assert_equal "gpt-4o-mini", @config.valid_model
        end

        # Temperature configuration tests
        test "temperature sets temperature value" do
          @config.temperature(0.7)

          assert_equal 0.7, @config.valid_temperature
        end

        test "temperature raises on value below 0" do
          error = assert_raises(ArgumentError) do
            @config.temperature(-0.1)
          end

          assert_match(/temperature must be between 0.0 and 1.0/, error.message)
        end

        test "temperature raises on value above 1" do
          error = assert_raises(ArgumentError) do
            @config.temperature(1.5)
          end

          assert_match(/temperature must be between 0.0 and 1.0/, error.message)
        end

        test "temperature accepts boundary value 0.0" do
          @config.temperature(0.0)

          assert_equal 0.0, @config.valid_temperature
        end

        test "temperature accepts boundary value 1.0" do
          @config.temperature(1.0)

          assert_equal 1.0, @config.valid_temperature
        end

        test "use_default_temperature! clears temperature value" do
          @config.temperature(0.5)
          @config.use_default_temperature!

          assert_nil @config.valid_temperature
        end

        test "valid_temperature returns nil when not set" do
          assert_nil @config.valid_temperature
        end

        # Model verification configuration tests
        test "verify_model_exists! enables model verification" do
          @config.verify_model_exists!

          assert @config.verify_model_exists?
        end

        test "no_verify_model_exists! disables model verification" do
          @config.verify_model_exists!
          @config.no_verify_model_exists!

          refute @config.verify_model_exists?
        end

        test "verify_model_exists? returns false by default" do
          refute @config.verify_model_exists?
        end

        test "assume_model_exists! is alias for no_verify_model_exists!" do
          @config.verify_model_exists!
          @config.assume_model_exists!

          refute @config.verify_model_exists?
        end

        # Display configuration tests
        test "show_prompt! enables prompt display" do
          @config.show_prompt!

          assert @config.show_prompt?
        end

        test "no_show_prompt! disables prompt display" do
          @config.show_prompt!
          @config.no_show_prompt!

          refute @config.show_prompt?
        end

        test "show_prompt? returns false by default" do
          refute @config.show_prompt?
        end

        test "show_response! enables response display" do
          @config.show_response!

          assert @config.show_response?
        end

        test "no_show_response! disables response display" do
          @config.no_show_response!

          refute @config.show_response?
        end

        test "show_response? returns true by default" do
          assert @config.show_response?
        end

        test "show_stats! enables stats display" do
          @config.show_stats!

          assert @config.show_stats?
        end

        test "no_show_stats! disables stats display" do
          @config.no_show_stats!

          refute @config.show_stats?
        end

        test "show_stats? returns true by default" do
          assert @config.show_stats?
        end

        test "display! enables all display options" do
          @config.no_display!
          @config.display!

          assert @config.show_prompt?
          assert @config.show_response?
          assert @config.show_stats?
        end

        test "no_display! disables all display options" do
          @config.display!
          @config.no_display!

          refute @config.show_prompt?
          refute @config.show_response?
          refute @config.show_stats?
        end

        test "quiet! is alias for no_display!" do
          @config.display!
          @config.quiet!

          refute @config.show_prompt?
          refute @config.show_response?
          refute @config.show_stats?
        end

        test "display? returns true when any display option is enabled" do
          @config.no_display!
          @config.show_prompt!

          assert @config.display?
        end

        test "display? returns false when all display options are disabled" do
          @config.no_display!

          refute @config.display?
        end
      end
    end
  end
end
