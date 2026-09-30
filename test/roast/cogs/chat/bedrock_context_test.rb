# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class ChatBedrockContextTest < ActiveSupport::TestCase
      def setup
        @cog = Chat.new(:test, ->(input) { input.prompt = "test message" })
      end

      test "bedrock provider passes AWS credentials and region to RubyLLM" do
        @cog.config.provider(:bedrock)

        with_aws_env(access_key: "akid", secret: "secret", token: "token", region: "us-west-2") do
          config = ruby_llm_config

          assert_equal "akid", config.bedrock_api_key
          assert_equal "secret", config.bedrock_secret_key
          assert_equal "token", config.bedrock_session_token
          assert_equal "us-west-2", config.bedrock_region
        end
      end

      test "bedrock provider does not require a session token" do
        @cog.config.provider(:bedrock)

        with_aws_env(access_key: "akid", secret: "secret", token: nil, region: "us-west-2") do
          assert_nil ruby_llm_config.bedrock_session_token
        end
      end

      test "bedrock provider treats a blank session token as unset" do
        @cog.config.provider(:bedrock)

        with_aws_env(access_key: "akid", secret: "secret", token: "", region: "us-west-2") do
          assert_nil ruby_llm_config.bedrock_session_token
        end
      end

      test "bedrock provider raises when the secret access key is missing" do
        @cog.config.provider(:bedrock)

        with_aws_env(access_key: "akid", secret: nil, token: nil, region: "us-west-2") do
          assert_raises(Cog::Config::InvalidConfigError) { ruby_llm_config }
        end
      end

      test "bedrock provider raises when the region is missing, even if AWS_DEFAULT_REGION is set" do
        @cog.config.provider(:bedrock)

        with_env("AWS_DEFAULT_REGION", "eu-west-1") do
          with_aws_env(access_key: "akid", secret: "secret", token: nil, region: nil) do
            assert_raises(Cog::Config::InvalidConfigError) { ruby_llm_config }
          end
        end
      end

      test "non-bedrock providers do not require AWS credentials" do
        @cog.config.provider(:openai)
        @cog.config.api_key("openai-key")

        with_aws_env(access_key: nil, secret: nil, token: nil, region: nil) do
          assert_equal "openai-key", ruby_llm_config.openai_api_key
        end
      end

      test "non-bedrock providers do not read AWS credentials" do
        @cog.config.provider(:openai)
        @cog.config.api_key("openai-key")

        with_aws_env(access_key: "akid", secret: "secret", token: "token", region: "us-west-2") do
          config = ruby_llm_config

          assert_equal "openai-key", config.openai_api_key
          assert_nil config.bedrock_api_key
          assert_nil config.bedrock_secret_key
          assert_nil config.bedrock_session_token
          assert_nil config.bedrock_region
        end
      end

      private

      def ruby_llm_config
        @cog.send(:ruby_llm_context).config
      end

      def with_aws_env(access_key:, secret:, token:, region:, &block)
        with_env("AWS_ACCESS_KEY_ID", access_key) do
          with_env("AWS_SECRET_ACCESS_KEY", secret) do
            with_env("AWS_SESSION_TOKEN", token) do
              with_env("AWS_REGION", region, &block)
            end
          end
        end
      end
    end
  end
end
