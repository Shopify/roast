# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ThinkingMessage < Message
              IGNORED_FIELDS = [
                :signature,
                :role,
              ].freeze

              #: String
              attr_reader :thinking

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @thinking = hash.delete(:thinking) || ""
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              #: (ClaudeInvocation::Context) -> String?
              def format(context)
                @thinking
              end
            end
          end
        end
      end
    end
  end
end
