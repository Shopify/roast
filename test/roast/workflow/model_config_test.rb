# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ModelConfigTest < ActiveSupport::TestCase
      test "returns correct token limit for known OpenAI models" do
        assert_equal 16_385, ModelConfig.max_tokens_for("gpt-3.5-turbo")
        assert_equal 8_192, ModelConfig.max_tokens_for("gpt-4")
        assert_equal 128_000, ModelConfig.max_tokens_for("gpt-4o")
      end
      
      test "returns correct token limit for known Anthropic models" do
        assert_equal 200_000, ModelConfig.max_tokens_for("claude-3-opus-20240229")
        assert_equal 200_000, ModelConfig.max_tokens_for("claude-3-5-sonnet-20241022")
      end
      
      test "returns correct token limit for known Google models" do
        assert_equal 32_768, ModelConfig.max_tokens_for("gemini-pro")
        assert_equal 1_048_576, ModelConfig.max_tokens_for("gemini-1.5-pro")
      end
      
      test "returns default token limit for unknown models" do
        assert_equal 4_096, ModelConfig.max_tokens_for("unknown-model-xyz")
        assert_equal 4_096, ModelConfig.max_tokens_for("llama-2-70b")
      end
      
      test "matches partial model names with prefix" do
        assert_equal 8_192, ModelConfig.max_tokens_for("gpt-4-0613")
        assert_equal 128_000, ModelConfig.max_tokens_for("gpt-4o-2024-05-13")
      end
      
      test "supported_models returns all models except default" do
        supported = ModelConfig.supported_models
        assert_includes supported, "gpt-4"
        assert_includes supported, "claude-3-opus-20240229"
        refute_includes supported, "default"
      end
      
      test "model_supported? returns true for known models and variants" do
        assert ModelConfig.model_supported?("gpt-4")
        assert ModelConfig.model_supported?("gpt-4-0613")
        assert ModelConfig.model_supported?("claude-3-opus-20240229")
        refute ModelConfig.model_supported?("unknown-model")
      end
      
      test "character_to_token_ratio_for returns nil for OpenAI models" do
        assert_nil ModelConfig.character_to_token_ratio_for("gpt-3.5-turbo")
        assert_nil ModelConfig.character_to_token_ratio_for("gpt-4")
        assert_nil ModelConfig.character_to_token_ratio_for("gpt-4o")
      end
      
      test "character_to_token_ratio_for returns correct ratio for Anthropic models" do
        assert_equal 0.33, ModelConfig.character_to_token_ratio_for("claude-3-opus-20240229")
        assert_equal 0.33, ModelConfig.character_to_token_ratio_for("claude-3-5-sonnet-20241022")
      end
      
      test "character_to_token_ratio_for returns correct ratio for Google models" do
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-pro")
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-1.5-pro")
      end
      
      test "character_to_token_ratio_for returns default ratio for unknown models" do
        assert_equal 0.25, ModelConfig.character_to_token_ratio_for("unknown-model-xyz")
        assert_equal 0.25, ModelConfig.character_to_token_ratio_for("llama-2-70b")
      end
      
      test "character_to_token_ratio_for matches partial model names" do
        assert_equal 0.33, ModelConfig.character_to_token_ratio_for("claude-3-opus-custom")
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-1.5-flash-001")
      end

      test "handles Gemini 2.x model patterns" do
        # Test key model families
        assert_equal 1_048_576, ModelConfig.max_tokens_for("gemini-2.0-flash")
        assert_equal 1_048_576, ModelConfig.max_tokens_for("gemini-2.5-flash")
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-2.0-flash")
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-2.5-flash")
      end

      test "handles Gemini versioning patterns" do
        # Test that versioned models map to base models
        assert_equal 1_048_576, ModelConfig.max_tokens_for("gemini-2.0-flash-001")
        assert_equal 1_048_576, ModelConfig.max_tokens_for("gemini-2.0-flash-exp")
        assert_equal 0.28, ModelConfig.character_to_token_ratio_for("gemini-2.0-flash-thinking-exp")
      end
    end
  end
end