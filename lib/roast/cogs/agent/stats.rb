# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      # Statistics about agent execution
      #
      # Contains metrics tracking the performance and resource usage of an agent execution,
      # including duration, conversation turns, token usage, and cost. Statistics are broken
      # down by model when multiple models are used during execution.
      class Stats
        include ActiveSupport::NumberHelper

        NO_VALUE = "---"

        # The total execution duration in milliseconds
        #
        # Measures the wall-clock time from when the agent started executing until it completed.
        # This includes all time spent on API calls, processing, and waiting.
        #
        #: Integer?
        attr_accessor :duration_ms

        # The number of conversation turns in the agent execution
        #
        # A turn represents one complete back-and-forth exchange between the user (or system)
        # and the agent. For example, if the user sends a prompt and the agent responds, that
        # is one turn. If the agent then uses a tool and responds again, that is another turn.
        #
        #: Integer?
        attr_accessor :num_turns

        # Aggregate token usage and cost across all models
        #
        # Provides the total input tokens, output tokens, and cost in USD for the entire
        # agent execution, regardless of which models were used.
        #
        # #### See Also
        # - `model_usage` - for per-model usage breakdown
        # - `Agent::Usage`
        #
        #: Usage
        attr_accessor :usage

        # Token usage and cost broken down by model
        #
        # A hash mapping model names (as strings) to their individual usage statistics.
        # This allows tracking how much each model contributed to the overall resource usage
        # when multiple models were used during execution.
        #
        # #### See Also
        # - `usage` - for aggregate usage across all models
        # - `Agent::Usage`
        #
        #: Hash[String, Usage]
        attr_accessor :model_usage

        def initialize
          @usage = Usage.new
          @model_usage = {}
        end

        # Get a human-readable string representation of the statistics
        #
        # Formats the statistics into a multi-line string with the following information:
        # - Number of turns
        # - Total duration (formatted as a human-readable duration)
        # - Total cost in USD (formatted with 6 decimal places)
        # - Per-model token usage (input and output tokens)
        #
        # Values that are not available are shown as "---".
        #
        #: () -> String
        def to_s
          lines = []
          lines << "Turns: #{num_turns.nil? ? NO_VALUE : number_to_human(num_turns)}"
          lines << "Duration: #{duration_ms.nil? ? NO_VALUE : ActiveSupport::Duration.build((duration_ms || 0) / 1000).inspect}"
          lines << "Cost (USD): $#{usage.cost_usd.nil? ? NO_VALUE : number_to_human(usage.cost_usd, precision: 6, significant: false)}"
          model_usage.each do |m, u|
            input_tokens = u.input_tokens.nil? ? NO_VALUE : number_to_human(u.input_tokens)
            output_tokens = u.output_tokens.nil? ? NO_VALUE : number_to_human(u.output_tokens)
            lines << "Tokens (#{m}): #{input_tokens} in, #{output_tokens} out"
          end
          lines.join("\n")
        end
      end
    end
  end
end
