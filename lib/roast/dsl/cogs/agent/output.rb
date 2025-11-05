# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class Output < Cog::Output
          include Cog::Output::WithJson

          #: String
          attr_reader :response

          #: String
          attr_reader :session

          private

          def json_text
            response
          end
        end
      end
    end
  end
end
