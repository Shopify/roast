# frozen_string_literal: true

module Roast
  module Workflow
    # Reports step completion with token consumption information
    class StepCompletionReporter
      def initialize(output: $stderr)
        @output = output
      end

      def report(step_name, tokens_consumed, total_tokens)
        formatted_consumed = number_with_delimiter(tokens_consumed)
        formatted_total = number_with_delimiter(total_tokens)

        @output.puts "✓ Complete: #{step_name} (consumed #{formatted_consumed} tokens, total #{formatted_total})"
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
