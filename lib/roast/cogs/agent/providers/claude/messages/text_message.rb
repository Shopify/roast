# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class TextMessage < Message
              #: Symbol?
              attr_reader :role

              #: String
              attr_reader :text

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @role = hash.delete(:role)
                @text = hash.delete(:text) || ""
                super(type:, hash:)
              end

              #: (ClaudeInvocation::Context) -> String
              def format(context)
                @text
              end
            end
          end
        end
      end
    end
  end
end
