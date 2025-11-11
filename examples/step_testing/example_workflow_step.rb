# frozen_string_literal: true

module Examples
  module StepTesting
    # Example workflow step that analyzes code quality
    class CodeAnalysisStep < Roast::Workflow::BaseStep
      def initialize(workflow, **kwargs)
        super
        @threshold = 0.8 # Quality threshold
      end

      def call
        file_path = workflow.resource&.target || workflow.file

        prompt(build_analysis_prompt(file_path))

        # Request JSON response with specific structure
        result = chat_completion(json: true, params: { temperature: 0.2 })

        # Validate and process result
        validate_result!(result)

        # Apply quality threshold
        result["pass"] = result["score"] >= @threshold

        result
      end

      private

      def build_analysis_prompt(file_path)
        <<~PROMPT
          Analyze the code quality of #{file_path}.

          Provide a JSON response with the following structure:
          {
            "score": <float between 0 and 1>,
            "issues": [
              {
                "type": "style|logic|performance|security",
                "severity": "low|medium|high",
                "description": "Issue description",
                "line": <line number or null>
              }
            ],
            "suggestions": ["suggestion 1", "suggestion 2"],
            "summary": "Overall assessment"
          }
        PROMPT
      end

      def validate_result!(result)
        raise "Invalid response format" unless result.is_a?(Hash)
        raise "Missing score" unless result["score"].is_a?(Numeric)
        raise "Missing issues" unless result["issues"].is_a?(Array)
        raise "Score out of range" unless (0..1).cover?(result["score"])
      end
    end
  end
end
