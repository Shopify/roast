# frozen_string_literal: true

module Roast
  module Workflow
    class ModelConfig
      # Model configuration including token limits and character-to-token ratios
      # These are conservative estimates to ensure safe operation
      MODEL_CONFIG = {
        # OpenAI models (use tiktoken for accurate counting)
        "gpt-3.5-turbo" => { max_tokens: 16_385, character_to_token_ratio: nil },
        "gpt-3.5-turbo-16k" => { max_tokens: 16_385, character_to_token_ratio: nil },
        "gpt-4" => { max_tokens: 8_192, character_to_token_ratio: nil },
        "gpt-4-32k" => { max_tokens: 32_768, character_to_token_ratio: nil },
        "gpt-4-turbo" => { max_tokens: 128_000, character_to_token_ratio: nil },
        "gpt-4-turbo-preview" => { max_tokens: 128_000, character_to_token_ratio: nil },
        "gpt-4o" => { max_tokens: 128_000, character_to_token_ratio: nil },
        "gpt-4o-mini" => { max_tokens: 128_000, character_to_token_ratio: nil },
        
        # Anthropic models (estimated ~3:1 character-to-token ratio)
        "claude-3-opus-20240229" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        "claude-3-sonnet-20240229" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        "claude-3-haiku-20240307" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        "claude-3-5-sonnet-20240620" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        "claude-3-5-sonnet-20241022" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        "claude-3-5-haiku-20241022" => { max_tokens: 200_000, character_to_token_ratio: 0.33 },
        
        # Google models (estimated ~3.5:1 character-to-token ratio)
        # Pattern matching supports: gemini-<generation>-<variation>[-<version>]
        "gemini-pro" => { max_tokens: 32_768, character_to_token_ratio: 0.28 },
        "gemini-1.5-pro" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        "gemini-1.5-flash" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        
        # Gemini 2.0 models - stable and experimental
        "gemini-2.0-flash" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        "gemini-2.0-flash-exp" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        "gemini-2.0-flash-thinking-exp" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        "gemini-2.0-pro-exp" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        
        # Gemini 2.5 models - preview and experimental versions
        "gemini-2.5-flash" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        "gemini-2.5-pro" => { max_tokens: 1_048_576, character_to_token_ratio: 0.28 },
        
        # Default for unknown models (conservative 4:1 ratio)
        "default" => { max_tokens: 4_096, character_to_token_ratio: 0.25 }
      }.freeze

      # Legacy hash for backward compatibility
      MODEL_LIMITS = MODEL_CONFIG.transform_values { |config| config[:max_tokens] }.freeze

      class << self
        def max_tokens_for(model)
          return MODEL_LIMITS[model] if MODEL_LIMITS.key?(model)
          
          # Try to match partial model names (e.g., "gpt-4" prefix)
          matching_key = MODEL_LIMITS.keys.find { |key| model.start_with?(key) }
          return MODEL_LIMITS[matching_key] if matching_key
          
          MODEL_LIMITS["default"]
        end
        
        def supported_models
          MODEL_LIMITS.keys - ["default"]
        end
        
        def model_supported?(model)
          supported_models.any? { |supported| model.start_with?(supported) }
        end
        
        def character_to_token_ratio_for(model)
          config = get_model_config(model)
          config[:character_to_token_ratio]
        end
        
        private
        
        def get_model_config(model)
          return MODEL_CONFIG[model] if MODEL_CONFIG.key?(model)
          
          # Try progressively simpler pattern matching, accepting defaults for unknown variants
          # This is more resilient to Google's frequent model naming changes
          
          # First try exact match with longest common prefix (works for most provider patterns)
          matching_key = MODEL_CONFIG.keys.find { |key| model.start_with?(key) }
          return MODEL_CONFIG[matching_key] if matching_key
          
          # For Gemini models, try a simple base pattern match as fallback
          if model.start_with?("gemini-")
            # Look for any gemini base pattern that matches (e.g., "gemini-2.0" matches both "gemini-2.0-flash" and "gemini-2.0-pro")
            base_match = MODEL_CONFIG.keys.find { |key| key.start_with?("gemini-") && model.start_with?(key.split("-")[0..1].join("-")) }
            return MODEL_CONFIG[base_match] if base_match
          end
          
          MODEL_CONFIG["default"]
        end
      end
    end
  end
end