# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Generic output from running a cog.
      # Cogs should extend this class with their own output types.
      class Output
        # @requires_ancestor: Output
        module WithJson
          #: () -> Hash[Symbol, untyped]
          def json!
            input = json_text
            return {} unless input

            # Look for JSON code blocks anywhere in the text
            # Matches ```json or ``` followed by content, then closing ```
            json_block_pattern = /```(?:json)?\s*\n(.*?)\n```/m
            match = input.match(json_block_pattern)
            text = match ? match[1] || input : input
            @json ||= JSON.parse(text.strip, symbolize_names: true)
          end

          #: () -> Hash[Symbol, untyped]?
          def json
            json!
          rescue JSON::ParserError
            nil
          end

          private

          # Cogs should implement this method to provide the text value that should be parsed to provide the 'json' attribute
          #
          #: () -> String?
          def json_text
            raise NotImplementedError
          end
        end
      end
    end
  end
end
