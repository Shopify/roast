# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class Usage
          #: Integer?
          attr_accessor :input_tokens

          #: Integer?
          attr_accessor :output_tokens

          #: Float?
          attr_accessor :cost_usd
        end
      end
    end
  end
end
