# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Output < Cog::Output
          include Cog::Output::WithJson
          include Cog::Output::WithText

          #: String
          attr_reader :response

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end

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
