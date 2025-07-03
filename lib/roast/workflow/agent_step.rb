# frozen_string_literal: true

module Roast
  module Workflow
    class AgentStep < BaseStep
      attr_accessor :include_context_summary, :continue, :resume

      def initialize(workflow, **kwargs)
        super
        # Set default values for agent-specific options
        @include_context_summary = false
        @continue = false
        @resume = nil
      end

      def call
        # For inline prompts (detected by plain text step names), use the name as the prompt
        # For file-based steps, load from the prompt file
        prompt_content = if name.plain_text?
          name.to_s
        else
          read_sidecar_prompt
        end

        # Use agent-specific configuration that was applied by StepLoader
        agent_options = {
          include_context_summary: @include_context_summary,
          continue: @continue,
          resume: @resume,
        }

        # Call CodingAgent directly with the prompt content and options
        result = Roast::Tools::CodingAgent.call(prompt_content, **agent_options)

        # Parse as JSON if json: true is configured (since CodingAgent response is not handled by Raix)
        if @json && result.is_a?(String)
          # Don't try to parse error messages as JSON
          if result.start_with?("Error running CodingAgent:")
            raise result
          end

          # Extract JSON from markdown code blocks anywhere in the response
          cleaned_result = extract_json_from_markdown(result)

          begin
            result = JSON.parse(cleaned_result)
          rescue JSON::ParserError => e
            raise "Failed to parse CodingAgent result as JSON: #{e.message}"
          end
        end

        # Process output if print_response is enabled
        process_output(result, print_response:)

        # Apply coercion if configured
        apply_coercion(result)
      end

      private

      def extract_json_from_markdown(text)
        # Look for JSON code blocks anywhere in the text
        # Matches ```json or ``` followed by content, then closing ```
        json_block_pattern = /```(?:json)?\s*\n(.*?)\n```/m

        match = text.match(json_block_pattern)
        if match
          # Return the content inside the code block
          match[1].strip
        else
          # No code block found, return original text
          text.strip
        end
      end
    end
  end
end
