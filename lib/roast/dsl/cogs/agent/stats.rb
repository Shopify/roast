# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class Stats
          include ActiveSupport::NumberHelper

          NO_VALUE = "---"

          #: Integer?
          attr_accessor :duration_ms

          #: Integer?
          attr_accessor :num_turns

          #: Usage
          attr_accessor :usage

          #: Hash[String, Usage]
          attr_accessor :model_usage

          def initialize
            @usage = Usage.new
            @model_usage = {}
          end

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
end
