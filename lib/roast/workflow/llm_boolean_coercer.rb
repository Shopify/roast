# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles intelligent coercion of LLM responses to boolean values
    class LlmBooleanCoercer
      # Patterns for detecting affirmative and negative responses
      EXPLICIT_TRUE_PATTERN = /\A(yes|y|true|t|1)\z/i
      EXPLICIT_FALSE_PATTERN = /\A(no|n|false|f|0)\z/i
      AFFIRMATIVE_PATTERN = /\b(yes|true|correct|affirmative|confirmed|indeed|right|positive|agree|definitely|certainly|absolutely)\b/
      NEGATIVE_PATTERN = /\b(no|false|incorrect|negative|denied|wrong|disagree|never)\b/

      class << self
        # Convert an LLM response to a boolean value
        #
        # @param result [Object] The value to coerce to boolean
        # @return [Boolean] The coerced boolean value
        def coerce(result)
          return true if result.is_a?(TrueClass)
          return false if result.is_a?(FalseClass) || result.nil?

          text = result.to_s.downcase.strip

          # Check for explicit boolean-like responses first
          return true if text =~ EXPLICIT_TRUE_PATTERN
          return false if text =~ EXPLICIT_FALSE_PATTERN

          # Then check for these words within longer responses
          has_affirmative = !!(text =~ AFFIRMATIVE_PATTERN)
          has_negative = !!(text =~ NEGATIVE_PATTERN)

          # Handle conflicts
          if has_affirmative && has_negative
            warn_ambiguity(result, "contains both affirmative and negative terms")
            false
          elsif has_affirmative
            true
          elsif has_negative
            false
          else
            warn_ambiguity(result, "no clear boolean indicators found")
            false
          end
        end

        private

        # Log a warning for ambiguous LLM boolean responses
        def warn_ambiguity(result, reason)
          Roast::Log.warn("Warning: Ambiguous LLM response for boolean conversion (#{reason}): '#{result.to_s.strip}'")
        end
      end
    end
  end
end
