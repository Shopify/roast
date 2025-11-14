# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class Output < Cog::Output
          include Cog::Output::WithJson
          include Cog::Output::WithText

          #: String
          attr_reader :response

          #: String
          attr_reader :session

          #: Stats
          attr_reader :stats

          private

          def json_text
            response
          end

          def raw_text
            response
          end
        end
      end
    end
  end
end
