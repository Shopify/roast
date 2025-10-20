# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Reports step completion with token consumption information
    class StepCompletionReporter
      def initialize(output: $stderr)
        @output = output
      end

      def report(step_name, tokens_consumed, total_tokens, context_manager: nil)
        formatted_consumed = number_with_delimiter(tokens_consumed)
        formatted_total = number_with_delimiter(total_tokens)

        base_message = "✓ Complete: #{step_name} (consumed #{formatted_consumed} tokens, total #{formatted_total})"

        # Add breakdown if context manager with agent stats is available
        if context_manager&.respond_to?(:statistics)
          stats = context_manager.statistics
          if stats[:agent_tokens] && stats[:agent_tokens] > 0
            general_tokens = stats[:general_tokens]
            agent_tokens = stats[:agent_tokens]
            base_message += " [general: #{number_with_delimiter(general_tokens)}, agent: #{number_with_delimiter(agent_tokens)}]"
          end
        end

        @output.puts base_message
        @output.puts
        @output.puts
      end

      private

      def number_with_delimiter(number)
        number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end
    end
  end
end
