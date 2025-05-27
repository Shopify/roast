# frozen_string_literal: true

module Roast
  module Helpers
    module ContentTruncator
      extend self

      def truncate_content(content, max_tokens, character_to_token_ratio: 0.25)
        # Use model-specific character-to-token ratio if provided, otherwise conservative default
        max_chars = (max_tokens / character_to_token_ratio).to_i

        if content.length <= max_chars
          content
        else
          truncated = content[0, max_chars]
          # Try to truncate at a line boundary if possible
          last_newline = truncated.rindex("\n")
          if last_newline && last_newline > max_chars * 0.8
            truncated = truncated[0, last_newline]
          end

          truncated + "\n\n[...truncated...]"
        end
      end
    end
  end
end
