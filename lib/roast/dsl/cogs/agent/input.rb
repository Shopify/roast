# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class Input < Cog::Input
          #: String?
          attr_accessor :prompt

          #: String?
          attr_accessor :session

          #: () -> void
          def initialize
            super
            @prompt = nil #: String?
          end

          #: () -> void
          def validate!
            valid_prompt!
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt ||= input_return_value
            end
          end

          #: () -> String
          def valid_prompt!
            valid_prompt = @prompt
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless valid_prompt.present?

            valid_prompt
          end
        end
      end
    end
  end
end
