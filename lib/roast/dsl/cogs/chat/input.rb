# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Input < Cog::Input
          #: String?
          attr_accessor :prompt

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless prompt.present?
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt = input_return_value
            end
          end
        end
      end
    end
  end
end
