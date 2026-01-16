# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ToolUseMessage < Message
              IGNORED_FIELDS = [
                :role,
              ].freeze

              #: String?
              attr_reader :id

              #: Symbol
              attr_reader :name

              #: Hash[Symbol, untyped]
              attr_reader :input

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @name = hash.delete(:name)&.downcase&.to_sym || :unknown
                @id = hash.delete(:id)
                @input = hash.delete(:input) || {}
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              #: (ClaudeInvocation::Context) -> String?
              def format(context)
                tool_use = ToolUse.new(name:, input:)
                tool_use.format
              end
            end
          end
        end
      end
    end
  end
end
