# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Generic output from running a cog.
      # Cogs should extend this class with their own output types.
      class Output
        # @requires_ancestor: Roast::DSL::Cog::Output
        module WithJson
          # Get parsed JSON from the output, raising an error if parsing fails
          #
          # This method attempts to parse JSON from the output text using multiple fallback strategies,
          # including extracting from code blocks and JSON-like patterns. If the input is nil or empty,
          # an empty hash is returned.
          #
          # #### See Also
          # - `json`
          #
          #: () -> Hash[Symbol, untyped]
          def json!
            input = json_text
            return {} if input.nil? || input.strip.empty?

            @json ||= parse_json_with_fallbacks(input)
          end

          # Get parsed JSON from the output, returning nil if parsing fails
          #
          # This method provides a safe alternative to `json!` that returns `nil` instead of raising
          # an error when JSON parsing fails.
          #
          # #### See Also
          # - `json!`
          #
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

          # Try parsing JSON from various possible formats in priority order
          #
          #: (String) -> Hash[Symbol, untyped]
          def parse_json_with_fallbacks(input)
            candidates = extract_json_candidates(input)
            candidates.each do |candidate|
              return JSON.parse(candidate.strip, symbolize_names: true)
            rescue JSON::ParserError, TypeError
              nil
            end
            raise JSON::ParserError, "Could not parse JSON from input:\n---\n#{input}\n---"
          end

          # Extract potential JSON strings in priority order
          #
          #: (String) -> Array[String]
          def extract_json_candidates(input)
            [
              input.strip, # 1. Entire input
              *extract_code_blocks(input, "json").reverse,    # 2. ```json blocks (last first)
              *extract_code_blocks(input, nil).reverse,       # 3. ``` blocks (last first)
              *extract_code_blocks(input, :any).reverse,      # 4. ```type blocks (last first)
              *extract_json_like_blocks(input), # 5. { } or [ ] blocks (longest first)
            ].compact.uniq
          end

          # Extract code blocks with optional language specifier
          # language can be: String (exact match), nil (no language), :any (any language except json/nil)
          #
          #: (String, String | Symbol | nil) -> Array[String]
          def extract_code_blocks(input, language)
            blocks = []
            parts = input.split("```")

            # Process pairs of splits (opening ``` and closing ```)
            (1...parts.length).step(2) do |i|
              block_with_header = parts[i]
              next unless block_with_header

              lines = block_with_header.lines
              first_line = lines.first&.strip || ""
              content = lines[1..].not_nil!.join

              case language
              when String
                blocks << content if first_line == language
              when nil
                blocks << content if first_line.empty?
              when :any
                blocks << content if !first_line.empty? && first_line != "json"
              end
            end

            blocks
          end

          # Extract blocks that look like JSON objects or arrays
          #
          #: (String) -> Array[String]
          def extract_json_like_blocks(input)
            blocks = []

            # Find all potential JSON blocks starting with { or [ and ending with } or ]
            input.scan(/^[ \t]*([{\[].*?[}\]])[ \t]*$/m) do |match|
              blocks << match[0]
            end

            # Also try to find JSON anywhere in the text (not just at line boundaries)
            input.scan(/([{\[](?:[^{}\[\]]|(?:\{(?:[^{}]|\{[^{}]*\})*\})|(?:\[(?:[^\[\]]|\[[^\[\]]*\])*\]))*[}\]])/m) do |match|
              blocks << match[0]
            end

            # Sort by length (longest first) and deduplicate
            blocks.uniq.sort_by { |b| -b.length }
          end
        end

        # @requires_ancestor: Roast::DSL::Cog::Output
        module WithText
          # Get the output as a single string with surrounding whitespace removed
          #
          # This method returns the text output with leading and trailing whitespace stripped.
          #
          # #### See Also
          # - `lines`
          #
          #: () -> String
          def text
            raw_text.strip
          end

          # Get the output as an array of lines with each line's whitespace stripped
          #
          # This method splits the output into individual lines and removes leading and trailing
          # whitespace from each line.
          #
          # #### See Also
          # - `text`
          #
          #: () -> Array[String]
          def lines
            raw_text.lines.map(&:strip)
          end

          private

          # Cogs should implement this method to provide the text value of their output
          #
          #: () -> String
          def raw_text
            raise NotImplementedError
          end
        end
      end
    end
  end
end
