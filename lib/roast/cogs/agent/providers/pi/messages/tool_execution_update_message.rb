# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolExecutionUpdateMessage < Message
              IGNORED_FIELDS = [
                :args,
                :partialResult,
              ].freeze

              #: String?
              attr_reader :tool_call_id

              #: String?
              attr_reader :tool_name

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @tool_call_id = hash.delete(:toolCallId)
                @tool_name = hash.delete(:toolName)
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end
            end
          end
        end
      end
    end
  end
end
